package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/wfu-work/downpeed-fluter/backend/internal/download"
	"github.com/wfu-work/downpeed-fluter/backend/pkg/api"
)

type batchCreateTasksRequest struct {
	Tasks []download.CreateTaskRequest `json:"tasks"`
}

type batchTaskActionRequest struct {
	IDs    []string `json:"ids"`
	Action string   `json:"action"`
}

type batchDeleteTasksRequest struct {
	IDs         []string `json:"ids"`
	DeleteFiles bool     `json:"deleteFiles"`
}

type batchTaskItemResult struct {
	Index int            `json:"index"`
	ID    string         `json:"id,omitempty"`
	Task  *download.Task `json:"task,omitempty"`
	Error *api.Error     `json:"error,omitempty"`
}

type batchTaskResult struct {
	Items     []batchTaskItemResult `json:"items"`
	Succeeded int                   `json:"succeeded"`
	Failed    int                   `json:"failed"`
}

type batchDeleteTaskItemResult struct {
	Index       int        `json:"index"`
	ID          string     `json:"id"`
	FileDeleted bool       `json:"fileDeleted,omitempty"`
	Error       *api.Error `json:"error,omitempty"`
}

type batchDeleteTaskResult struct {
	Items     []batchDeleteTaskItemResult `json:"items"`
	Succeeded int                         `json:"succeeded"`
	Failed    int                         `json:"failed"`
}

func (s *Server) createTask(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, maxResolveRequestBytes)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	var input download.CreateTaskRequest
	if err := decoder.Decode(&input); err != nil {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_request", "The request body must contain a valid download task.", false)
		return
	}
	if err := ensureJSONEnd(decoder); err != nil {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_request", "The request body must contain one JSON object.", false)
		return
	}
	task, err := s.tasks.Create(r.Context(), input)
	if err != nil {
		writeTaskServiceError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, api.Envelope[download.Task]{
		Data:      task,
		RequestID: requestIDFrom(r),
	})
}

func (s *Server) createTasksBatch(w http.ResponseWriter, r *http.Request) {
	var input batchCreateTasksRequest
	if !decodeBatchRequest(w, r, &input) {
		return
	}
	if len(input.Tasks) == 0 || len(input.Tasks) > maxBatchTasks {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_batch_size", "A batch must contain between 1 and 100 tasks.", false)
		return
	}

	result := batchTaskResult{Items: make([]batchTaskItemResult, 0, len(input.Tasks))}
	for index, request := range input.Tasks {
		task, err := s.tasks.Create(r.Context(), request)
		item := batchTaskItemResult{Index: index}
		if err != nil {
			_, item.Error = taskServiceAPIError(err)
			result.Failed++
		} else {
			item.ID = task.ID
			item.Task = &task
			result.Succeeded++
		}
		result.Items = append(result.Items, item)
	}
	writeJSON(w, http.StatusOK, api.Envelope[batchTaskResult]{
		Data:      result,
		RequestID: requestIDFrom(r),
	})
}

func (s *Server) actOnTasksBatch(w http.ResponseWriter, r *http.Request) {
	var input batchTaskActionRequest
	if !decodeBatchRequest(w, r, &input) {
		return
	}
	if len(input.IDs) == 0 || len(input.IDs) > maxBatchTasks {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_batch_size", "A batch must contain between 1 and 100 task IDs.", false)
		return
	}
	if input.Action != "pause" && input.Action != "resume" && input.Action != "cancel" {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_batch_action", "The batch action must be pause, resume, or cancel.", false)
		return
	}

	result := batchTaskResult{Items: make([]batchTaskItemResult, 0, len(input.IDs))}
	for index, id := range input.IDs {
		item := batchTaskItemResult{Index: index, ID: id}
		var (
			task download.Task
			err  error
		)
		switch input.Action {
		case "pause":
			task, err = s.tasks.Pause(r.Context(), id)
		case "resume":
			task, err = s.tasks.Resume(r.Context(), id)
		case "cancel":
			task, err = s.tasks.Cancel(r.Context(), id)
		}
		if err != nil {
			_, item.Error = taskServiceAPIError(err)
			result.Failed++
		} else {
			item.Task = &task
			result.Succeeded++
		}
		result.Items = append(result.Items, item)
	}
	writeJSON(w, http.StatusOK, api.Envelope[batchTaskResult]{
		Data:      result,
		RequestID: requestIDFrom(r),
	})
}

func (s *Server) deleteTasksBatch(w http.ResponseWriter, r *http.Request) {
	var input batchDeleteTasksRequest
	if !decodeBatchRequest(w, r, &input) {
		return
	}
	if len(input.IDs) == 0 || len(input.IDs) > maxBatchTasks {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_batch_size", "A batch must contain between 1 and 100 task IDs.", false)
		return
	}
	writeJSON(w, http.StatusOK, api.Envelope[batchDeleteTaskResult]{
		Data:      s.deleteTaskIDs(r.Context(), input.IDs, input.DeleteFiles),
		RequestID: requestIDFrom(r),
	})
}

func (s *Server) deleteCompletedTasks(w http.ResponseWriter, r *http.Request) {
	tasks, err := s.tasks.List(r.Context())
	if err != nil {
		writeTaskServiceError(w, r, err)
		return
	}
	ids := make([]string, 0, len(tasks))
	for _, task := range tasks {
		if task.State == download.TaskStateCompleted {
			ids = append(ids, task.ID)
		}
	}
	writeJSON(w, http.StatusOK, api.Envelope[batchDeleteTaskResult]{
		Data:      s.deleteTaskIDs(r.Context(), ids, false),
		RequestID: requestIDFrom(r),
	})
}

func (s *Server) deleteTaskIDs(ctx context.Context, ids []string, deleteFiles bool) batchDeleteTaskResult {
	result := batchDeleteTaskResult{Items: make([]batchDeleteTaskItemResult, 0, len(ids))}
	for index, id := range ids {
		item := batchDeleteTaskItemResult{Index: index, ID: id}
		deleted, err := s.tasks.Delete(ctx, id, deleteFiles)
		if err != nil {
			_, item.Error = taskServiceAPIError(err)
			result.Failed++
		} else {
			item.FileDeleted = deleted.FileDeleted
			result.Succeeded++
		}
		result.Items = append(result.Items, item)
	}
	return result
}

func decodeBatchRequest(w http.ResponseWriter, r *http.Request, destination any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, maxBatchRequestBytes)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(destination); err != nil {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_request", "The request body must contain a valid task batch.", false)
		return false
	}
	if err := ensureJSONEnd(decoder); err != nil {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_request", "The request body must contain one JSON object.", false)
		return false
	}
	return true
}

func (s *Server) listTasks(w http.ResponseWriter, r *http.Request) {
	tasks, err := s.tasks.List(r.Context())
	if err != nil {
		writeTaskServiceError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, api.Envelope[[]download.Task]{
		Data:      tasks,
		RequestID: requestIDFrom(r),
	})
}

func (s *Server) getTask(w http.ResponseWriter, r *http.Request) {
	task, err := s.tasks.Get(r.Context(), r.PathValue("id"))
	if err != nil {
		writeTaskServiceError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, api.Envelope[download.Task]{
		Data:      task,
		RequestID: requestIDFrom(r),
	})
}

func (s *Server) cancelTask(w http.ResponseWriter, r *http.Request) {
	task, err := s.tasks.Cancel(r.Context(), r.PathValue("id"))
	if err != nil {
		writeTaskServiceError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, api.Envelope[download.Task]{
		Data:      task,
		RequestID: requestIDFrom(r),
	})
}

func (s *Server) deleteTask(w http.ResponseWriter, r *http.Request) {
	deleteFile, ok := readDeleteFilesQuery(w, r)
	if !ok {
		return
	}
	result, err := s.tasks.Delete(r.Context(), r.PathValue("id"), deleteFile)
	if err != nil {
		writeTaskServiceError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, api.Envelope[download.DeleteTaskResult]{
		Data:      result,
		RequestID: requestIDFrom(r),
	})
}

func readDeleteFilesQuery(w http.ResponseWriter, r *http.Request) (bool, bool) {
	value := r.URL.Query().Get("deleteFiles")
	if value == "" {
		return false, true
	}
	parsed, err := strconv.ParseBool(value)
	if err != nil {
		writeAPIError(w, r, http.StatusBadRequest, "invalid_request", "deleteFiles must be true or false.", false)
		return false, false
	}
	return parsed, true
}

func (s *Server) pauseTask(w http.ResponseWriter, r *http.Request) {
	task, err := s.tasks.Pause(r.Context(), r.PathValue("id"))
	if err != nil {
		writeTaskServiceError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, api.Envelope[download.Task]{
		Data:      task,
		RequestID: requestIDFrom(r),
	})
}

func (s *Server) resumeTask(w http.ResponseWriter, r *http.Request) {
	task, err := s.tasks.Resume(r.Context(), r.PathValue("id"))
	if err != nil {
		writeTaskServiceError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, api.Envelope[download.Task]{
		Data:      task,
		RequestID: requestIDFrom(r),
	})
}

func (s *Server) retryTask(w http.ResponseWriter, r *http.Request) {
	task, err := s.tasks.Retry(r.Context(), r.PathValue("id"))
	if err != nil {
		writeTaskServiceError(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, api.Envelope[download.Task]{
		Data:      task,
		RequestID: requestIDFrom(r),
	})
}

func (s *Server) events(w http.ResponseWriter, r *http.Request) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		writeAPIError(w, r, http.StatusInternalServerError, "events_unavailable", "Live task events are unavailable.", true)
		return
	}
	w.Header().Set("Content-Type", "text/event-stream; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")
	_, _ = fmt.Fprint(w, ": connected\n\n")
	flusher.Flush()

	events := s.tasks.Subscribe(r.Context())
	tasks, err := s.tasks.List(r.Context())
	if err != nil {
		return
	}
	for _, task := range tasks {
		if err = writeSSEEvent(w, download.TaskEvent{Type: download.TaskUpdatedEvent, Task: task}); err != nil {
			return
		}
	}
	flusher.Flush()

	heartbeat := time.NewTicker(15 * time.Second)
	defer heartbeat.Stop()
	for {
		select {
		case <-r.Context().Done():
			return
		case event, open := <-events:
			if !open {
				return
			}
			if err = writeSSEEvent(w, event); err != nil {
				return
			}
			flusher.Flush()
		case <-heartbeat.C:
			if _, err = fmt.Fprint(w, ": keep-alive\n\n"); err != nil {
				return
			}
			flusher.Flush()
		}
	}
}

func writeSSEEvent(w http.ResponseWriter, event download.TaskEvent) error {
	value, err := json.Marshal(event)
	if err != nil {
		return err
	}
	_, err = fmt.Fprintf(w, "event: %s\ndata: %s\n\n", event.Type, value)
	return err
}

func writeTaskServiceError(w http.ResponseWriter, r *http.Request, err error) {
	status, apiError := taskServiceAPIError(err)
	writeAPIError(w, r, status, apiError.Code, apiError.Message, apiError.Retryable)
}

func taskServiceAPIError(err error) (int, *api.Error) {
	switch {
	case errors.Is(err, download.ErrInvalidRequest):
		return http.StatusBadRequest, &api.Error{Code: "invalid_request", Message: "Enter a valid absolute download URL.", Retryable: false}
	case errors.Is(err, download.ErrUnsupportedScheme):
		return http.StatusBadRequest, &api.Error{Code: "unsupported_scheme", Message: "Only HTTP and HTTPS download URLs are supported.", Retryable: false}
	case errors.Is(err, download.ErrInvalidDestination):
		return http.StatusBadRequest, &api.Error{Code: "invalid_destination", Message: "Select an existing absolute download directory and a valid file name.", Retryable: false}
	case errors.Is(err, download.ErrInvalidSchedule):
		return http.StatusBadRequest, &api.Error{Code: "invalid_schedule", Message: "Choose a future time for the download to start.", Retryable: false}
	case errors.Is(err, download.ErrDestinationExists):
		return http.StatusConflict, &api.Error{Code: "destination_exists", Message: "A file already exists at the selected destination.", Retryable: false}
	case errors.Is(err, download.ErrTaskNotFound):
		return http.StatusNotFound, &api.Error{Code: "task_not_found", Message: "The download task does not exist.", Retryable: false}
	case errors.Is(err, download.ErrTaskInvalidState):
		return http.StatusConflict, &api.Error{Code: "invalid_task_state", Message: "The task state does not allow this operation.", Retryable: false}
	case errors.Is(err, download.ErrTaskRetryNotAllowed):
		return http.StatusConflict, &api.Error{Code: "task_not_retryable", Message: "This failed task cannot be retried safely. Create a new task instead.", Retryable: false}
	case errors.Is(err, download.ErrResumeNotSupported):
		return http.StatusConflict, &api.Error{Code: "resume_not_supported", Message: "The task cannot be resumed safely because the remote resource has no usable validator.", Retryable: false}
	case errors.Is(err, download.ErrPartialFileChanged):
		return http.StatusConflict, &api.Error{Code: "partial_file_changed", Message: "The partial download file changed outside Downpeed.", Retryable: false}
	case errors.Is(err, download.ErrTaskFileDelete):
		return http.StatusConflict, &api.Error{Code: "task_file_delete_failed", Message: "The downloaded file could not be deleted safely.", Retryable: false}
	case errors.Is(err, download.ErrUnsupportedProtocol):
		return http.StatusNotImplemented, &api.Error{Code: "bt_transfer_unavailable", Message: "BT transfer is not enabled in this engine.", Retryable: false}
	case errors.Is(err, download.ErrBTPeerRequired):
		return http.StatusBadRequest, &api.Error{Code: "bt_peer_required", Message: "Add at least one allowed explicit Peer because Tracker and DHT discovery are disabled.", Retryable: false}
	case errors.Is(err, download.ErrBTPeerInvalid):
		return http.StatusBadRequest, &api.Error{Code: "bt_peer_invalid", Message: "Explicit Peers must use allowed public IPv4 addresses and valid ports.", Retryable: false}
	case errors.Is(err, download.ErrBTFileSelection):
		return http.StatusBadRequest, &api.Error{Code: "bt_file_selection_invalid", Message: "Select at least one valid Torrent file without duplicates.", Retryable: false}
	case errors.Is(err, download.ErrBTMetadataInvalid), errors.Is(err, download.ErrBTMetadataTooLarge), errors.Is(err, download.ErrBTPathUnsafe):
		return http.StatusBadRequest, &api.Error{Code: "bt_metadata_invalid", Message: "The Torrent metadata is malformed or unsupported.", Retryable: false}
	default:
		return http.StatusInternalServerError, &api.Error{Code: "task_operation_failed", Message: "The engine could not update the download task.", Retryable: true}
	}
}
