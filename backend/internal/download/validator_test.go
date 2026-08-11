package download

import "testing"

func TestResourceValidatorPrefersStrongETagThenLastModified(t *testing.T) {
	lastModified := "Tue, 11 Aug 2026 01:02:03 GMT"
	strong, err := NormalizeResourceValidator(`"release-v1"`, lastModified)
	if err != nil {
		t.Fatal(err)
	}
	if strong.StrongETag() != `"release-v1"` || strong.IfRangeValue() != `"release-v1"` {
		t.Fatalf("strong validator = %#v", strong)
	}

	weak, err := NormalizeResourceValidator(`W/"release-v1"`, lastModified)
	if err != nil {
		t.Fatal(err)
	}
	if weak.StrongETag() != "" || weak.IfRangeValue() != lastModified {
		t.Fatalf("weak validator = %#v", weak)
	}
}

func TestResourceValidatorRejectsHeaderInjectionAndMalformedDates(t *testing.T) {
	for _, input := range []struct {
		etag         string
		lastModified string
	}{
		{etag: "\"safe\"\r\nX-Injected: true"},
		{lastModified: "tomorrow"},
	} {
		if _, err := NormalizeResourceValidator(input.etag, input.lastModified); err == nil {
			t.Fatalf("NormalizeResourceValidator(%q, %q) error = nil", input.etag, input.lastModified)
		}
	}
}
