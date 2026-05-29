// Translates grpc/status errors (the legacy shape every handler
// returns via status.Errorf(codes.X, ...)) into *connect.Error with
// the equivalent connect.Code. Without this interceptor, Connect-Go
// sees plain errors and wraps them as connect.CodeUnknown — and
// the browser surfaces them as the generic "Wystąpił nieznany błąd"
// instead of the specific code-based copy
// (PermissionDenied / FailedPrecondition / InvalidArgument).
//
// Why an interceptor (vs translating at each adapter method): the
// adapter forwards every error back unchanged via `if err != nil
// { return nil, err }`; doing the translation in one place is
// cheaper and impossible to forget when a new RPC lands.
//
// Errors that are already *connect.Error pass through untouched, so
// handlers that opt into the Connect-native shape still work.
//
// Also slogs the original error type + message so we have ground
// truth in Cloud Logging — without this, opaque 500s from billing-svc
// were invisible (no panic, no server log, just the Code.Unknown on
// the wire).

package grpc

import (
	"context"
	"errors"
	"fmt"
	"log/slog"

	"connectrpc.com/connect"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// ConnectErrorInterceptor must run AFTER the handler so it can
// intercept the handler's return value. It MUST be added LAST in the
// connect.WithInterceptors chain because Connect interceptors compose
// in unary-call order (first interceptor = outermost wrapper).
func ConnectErrorInterceptor() connect.UnaryInterceptorFunc {
	return func(next connect.UnaryFunc) connect.UnaryFunc {
		return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
			resp, err := next(ctx, req)
			if err == nil {
				return resp, nil
			}

			// Already a connect.Error → pass through.
			var connectErr *connect.Error
			if errors.As(err, &connectErr) {
				return nil, err
			}

			// grpc/status error → translate code + message.
			if st, ok := status.FromError(err); ok {
				slog.WarnContext(ctx, "connect: translating grpc/status error",
					"procedure", req.Spec().Procedure,
					"grpc_code", st.Code().String(),
					"message", st.Message())
				return nil, connect.NewError(grpcCodeToConnectCode(st.Code()),
					errors.New(st.Message()))
			}

			// Unknown error shape — log it so we can find out why.
			slog.ErrorContext(ctx, "connect: handler returned unrecognised error",
				"procedure", req.Spec().Procedure,
				"err_type", typeName(err),
				"err", err.Error())
			return nil, connect.NewError(connect.CodeUnknown, err)
		}
	}
}

// grpcCodeToConnectCode is a 1:1 mapping. Both code spaces use the
// canonical gRPC names so it's just a numeric translation; keeping it
// explicit makes any future code drift obvious in code review.
func grpcCodeToConnectCode(c codes.Code) connect.Code {
	switch c {
	case codes.Canceled:
		return connect.CodeCanceled
	case codes.Unknown:
		return connect.CodeUnknown
	case codes.InvalidArgument:
		return connect.CodeInvalidArgument
	case codes.DeadlineExceeded:
		return connect.CodeDeadlineExceeded
	case codes.NotFound:
		return connect.CodeNotFound
	case codes.AlreadyExists:
		return connect.CodeAlreadyExists
	case codes.PermissionDenied:
		return connect.CodePermissionDenied
	case codes.ResourceExhausted:
		return connect.CodeResourceExhausted
	case codes.FailedPrecondition:
		return connect.CodeFailedPrecondition
	case codes.Aborted:
		return connect.CodeAborted
	case codes.OutOfRange:
		return connect.CodeOutOfRange
	case codes.Unimplemented:
		return connect.CodeUnimplemented
	case codes.Internal:
		return connect.CodeInternal
	case codes.Unavailable:
		return connect.CodeUnavailable
	case codes.DataLoss:
		return connect.CodeDataLoss
	case codes.Unauthenticated:
		return connect.CodeUnauthenticated
	default:
		return connect.CodeUnknown
	}
}

func typeName(v any) string {
	if v == nil {
		return "<nil>"
	}
	return fmt.Sprintf("%T", v)
}
