#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* desktop_actions_channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static FlMethodResponse* desktop_action_error(const gchar* code,
                                              const gchar* message) {
  return FL_METHOD_RESPONSE(fl_method_error_response_new(code, message, nullptr));
}

static gboolean read_absolute_file_path(FlMethodCall* method_call,
                                        const gchar** path,
                                        FlMethodResponse** response) {
  FlValue* arguments = fl_method_call_get_args(method_call);
  FlValue* path_value =
      arguments == nullptr ||
              fl_value_get_type(arguments) != FL_VALUE_TYPE_MAP
          ? nullptr
          : fl_value_lookup_string(arguments, "path");
  if (path_value == nullptr ||
      fl_value_get_type(path_value) != FL_VALUE_TYPE_STRING) {
    *response = desktop_action_error("invalid_argument",
                                     "An absolute file path is required.");
    return FALSE;
  }
  *path = fl_value_get_string(path_value);
  if (*path == nullptr || !g_path_is_absolute(*path)) {
    *response = desktop_action_error("invalid_argument",
                                     "An absolute file path is required.");
    return FALSE;
  }
  g_autoptr(GFile) file = g_file_new_for_path(*path);
  if (!g_file_query_exists(file, nullptr) ||
      g_file_query_file_type(file, G_FILE_QUERY_INFO_NONE, nullptr) !=
          G_FILE_TYPE_REGULAR) {
    *response = desktop_action_error(
        "file_not_found", "The completed file no longer exists.");
    return FALSE;
  }
  return TRUE;
}

static gboolean open_uri(const gchar* uri) {
  g_autoptr(GError) error = nullptr;
  return g_app_info_launch_default_for_uri(uri, nullptr, &error);
}

static gboolean reveal_file(const gchar* path) {
  g_autoptr(GFile) file = g_file_new_for_path(path);
  g_autofree gchar* uri = g_file_get_uri(file);
  const gchar* uris[] = {uri, nullptr};
  g_autoptr(GError) error = nullptr;
  g_autoptr(GDBusConnection) connection =
      g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (connection != nullptr) {
    g_autoptr(GVariant) reply = g_dbus_connection_call_sync(
        connection, "org.freedesktop.FileManager1",
        "/org/freedesktop/FileManager1", "org.freedesktop.FileManager1",
        "ShowItems", g_variant_new("(^ass)", uris, ""), nullptr,
        G_DBUS_CALL_FLAGS_NONE, 3000, nullptr, &error);
    if (reply != nullptr) {
      return TRUE;
    }
  }

  g_autoptr(GFile) parent = g_file_get_parent(file);
  if (parent == nullptr) {
    return FALSE;
  }
  g_autofree gchar* parent_uri = g_file_get_uri(parent);
  return open_uri(parent_uri);
}

static const gchar* string_argument(FlMethodCall* method_call,
                                    const gchar* name) {
  FlValue* arguments = fl_method_call_get_args(method_call);
  FlValue* value = arguments == nullptr ||
                           fl_value_get_type(arguments) != FL_VALUE_TYPE_MAP
                       ? nullptr
                       : fl_value_lookup_string(arguments, name);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_STRING) {
    return nullptr;
  }
  return fl_value_get_string(value);
}

static void desktop_actions_method_call_cb(FlMethodChannel* channel,
                                           FlMethodCall* method_call,
                                           gpointer user_data) {
  (void)channel;
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (g_strcmp0(method, "showCompletionNotification") == 0) {
    const gchar* id = string_argument(method_call, "id");
    const gchar* title = string_argument(method_call, "title");
    const gchar* body = string_argument(method_call, "body");
    if (id == nullptr || *id == '\0' || title == nullptr || *title == '\0' ||
        body == nullptr || *body == '\0') {
      response = desktop_action_error("invalid_argument",
                                      "Notification text is required.");
    } else {
      g_autoptr(GNotification) notification = g_notification_new(title);
      g_notification_set_body(notification, body);
      g_application_send_notification(G_APPLICATION(self), id, notification);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    }
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  if (g_strcmp0(method, "openFile") == 0 ||
      g_strcmp0(method, "revealFile") == 0) {
    const gchar* path = nullptr;
    FlMethodResponse* path_error = nullptr;
    if (!read_absolute_file_path(method_call, &path, &path_error)) {
      response = path_error;
    } else {
      gboolean opened = FALSE;
      if (g_strcmp0(method, "openFile") == 0) {
        g_autoptr(GFile) file = g_file_new_for_path(path);
        g_autofree gchar* uri = g_file_get_uri(file);
        opened = open_uri(uri);
      } else {
        opened = reveal_file(path);
      }
      response = opened
                     ? FL_METHOD_RESPONSE(
                           fl_method_success_response_new(nullptr))
                     : desktop_action_error(
                           "open_failed",
                           "The system could not open the completed file.");
    }
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  fl_method_call_respond(method_call, response, nullptr);
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static void set_window_icon(GtkWindow* window) {
  g_autoptr(GError) error = nullptr;
  g_autofree gchar* executable_path = g_file_read_link("/proc/self/exe", &error);
  if (executable_path == nullptr) {
    g_warning("Unable to locate the Downpeed application icon: %s",
              error->message);
    return;
  }

  g_autofree gchar* executable_dir = g_path_get_dirname(executable_path);
  g_autofree gchar* icon_path =
      g_build_filename(executable_dir, "data", "app_icon.png", nullptr);
  if (!gtk_window_set_icon_from_file(window, icon_path, &error)) {
    g_warning("Unable to load the Downpeed application icon: %s",
              error->message);
  }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Downpeed");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Downpeed");
  }

  set_window_icon(window);
  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->desktop_actions_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "com.xiaoxi.downpeed/desktop_actions", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->desktop_actions_channel, desktop_actions_method_call_cb, self,
      nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_object(&self->desktop_actions_channel);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
