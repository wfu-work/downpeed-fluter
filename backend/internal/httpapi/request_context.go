package httpapi

import "context"

type requestIDKey struct{}

func withRequestID(ctx context.Context, requestID string) context.Context {
	return context.WithValue(ctx, requestIDKey{}, requestID)
}

func requestIDFromContext(ctx context.Context) string {
	requestID, _ := ctx.Value(requestIDKey{}).(string)
	return requestID
}

type contextCarrier interface {
	Context() context.Context
}

func requestIDFrom(request contextCarrier) string {
	return requestIDFromContext(request.Context())
}
