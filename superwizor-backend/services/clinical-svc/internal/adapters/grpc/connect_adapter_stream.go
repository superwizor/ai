package grpc

// Most strumieniowy Connect → gRPC dla AskPatientQuestion.
//
// Reszta ConnectAdaptera to mechaniczne opakowania 1:1, bo wszystkie
// pozostałe RPC są unarne. AskPatientQuestion jest pierwszym
// server-streamingiem w clinical-svc i wymaga przejściówki, bo obie
// strony mają inny kształt strumienia:
//
//	gRPC:    func(req *Request, stream grpc.ServerStreamingServer[Response]) error
//	Connect: func(ctx, *connect.Request[Request], *connect.ServerStream[Response]) error
//
// Bez tej metody ConnectAdapter nie spełnia ClinicalServiceHandler
// i clinical-svc/cmd/server się NIE KOMPILUJE. Na gałęzi feat/chat-window
// build przechodził tylko dlatego, że gen/go jest w .gitignore — lokalnie
// wygenerowany kod nie znał jeszcze tego RPC. CI, które robi
// `buf generate` przed budowaniem, zapaliłoby się od razu.

import (
	"context"

	"connectrpc.com/connect"
	"google.golang.org/grpc/metadata"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
)

// connectServerStream podszywa się pod grpc.ServerStreamingServer, a
// wysyłkę przekazuje do strumienia Connect.
//
// Metody metadanych są świadomie puste: Connect obsługuje nagłówki
// i trailery własnym mechanizmem na *connect.ServerStream, a handler
// AskPatientQuestion i tak z nich nie korzysta — czyta wyłącznie
// stream.Context() dla autoryzacji. Gdyby kiedyś zaczął ustawiać
// metadane, trzeba je tu przepiąć na stream.ResponseHeader().
type connectServerStream struct {
	ctx    context.Context
	stream *connect.ServerStream[clinicalv1.AskPatientQuestionResponse]
}

func (s *connectServerStream) Send(m *clinicalv1.AskPatientQuestionResponse) error {
	return s.stream.Send(m)
}

func (s *connectServerStream) Context() context.Context { return s.ctx }

func (s *connectServerStream) SendMsg(m any) error {
	msg, ok := m.(*clinicalv1.AskPatientQuestionResponse)
	if !ok {
		return connect.NewError(connect.CodeInternal, errUnexpectedStreamMessage)
	}
	return s.stream.Send(msg)
}

// RecvMsg nie ma sensu dla server-streamingu — klient nic nie wysyła
// po pierwszym żądaniu. Zwracamy błąd zamiast cicho blokować.
func (s *connectServerStream) RecvMsg(any) error {
	return connect.NewError(connect.CodeUnimplemented, errRecvOnServerStream)
}

func (s *connectServerStream) SetHeader(metadata.MD) error  { return nil }
func (s *connectServerStream) SendHeader(metadata.MD) error { return nil }
func (s *connectServerStream) SetTrailer(metadata.MD)       {}

// AskPatientQuestion przekazuje strumień z Connect do gRPC-owego
// handlera. Kontekst bierzemy z Connect, bo to on niesie nagłówek
// autoryzacji, na którym opiera się requireTherapistDataAccess.
func (a *ConnectAdapter) AskPatientQuestion(
	ctx context.Context,
	req *connect.Request[clinicalv1.AskPatientQuestionRequest],
	stream *connect.ServerStream[clinicalv1.AskPatientQuestionResponse],
) error {
	return a.s.AskPatientQuestion(req.Msg, &connectServerStream{ctx: ctx, stream: stream})
}

// Błędy mostu — osobne zmienne, żeby dało się je porównywać w testach.
var (
	errUnexpectedStreamMessage = errStr("unexpected message type on AskPatientQuestion stream")
	errRecvOnServerStream      = errStr("RecvMsg is not supported on a server stream")
)

type errStr string

func (e errStr) Error() string { return string(e) }
