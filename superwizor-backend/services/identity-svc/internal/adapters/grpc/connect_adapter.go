package grpc

import (
	"context"

	"connectrpc.com/connect"
	"google.golang.org/protobuf/types/known/emptypb"

	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
)

// ConnectAdapter wraps *Server (the gRPC IdentityServiceServer
// implementation) and exposes it as a Connect-RPC handler. Each
// method just unwraps the connect.Request, calls the underlying gRPC
// method on the embedded Server, and wraps the response.
//
// Why this exists: the generated identityv1connect.IdentityServiceHandler
// interface uses connect.Request[T] / connect.Response[T] wrapper
// types, while our actual handlers use bare proto types (that's what
// the gRPC interface requires). Implementing both interfaces on the
// same struct would mean each method has the wrong signature for one
// of them. The adapter is mechanical — same logic, two surfaces.
//
// Both share the same Server instance + therefore the same auth
// context resolution, DB connection, audit-event helpers etc. Errors
// from the gRPC method (already wrapped with status.Error) are passed
// straight through — Connect interprets them as the equivalent gRPC
// codes on the wire.
//
// Reference: docs/18 §5 (R1 — Connect natively speaks gRPC + gRPC-Web
// + Connect from one endpoint), docs/19 §1.9 / commit baf6e3f
// (the original deferral note).
type ConnectAdapter struct {
	s *Server
}

func NewConnectAdapter(s *Server) *ConnectAdapter { return &ConnectAdapter{s: s} }

// Compile-time assertion that ConnectAdapter satisfies the generated
// interface. If a new RPC is added to identity.proto and we forget to
// wrap it here, this line catches it at build time.
// var _ identityv1connect.IdentityServiceHandler = (*ConnectAdapter)(nil)
// (Commented to avoid an import cycle in cmd/server; main.go does the
// equivalent check via the call to NewIdentityServiceHandler.)

func (a *ConnectAdapter) ValidateToken(ctx context.Context, req *connect.Request[identityv1.ValidateTokenRequest]) (*connect.Response[identityv1.UserContext], error) {
	resp, err := a.s.ValidateToken(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) GetUser(ctx context.Context, req *connect.Request[identityv1.GetUserRequest]) (*connect.Response[identityv1.User], error) {
	resp, err := a.s.GetUser(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) GetUserByFirebaseUID(ctx context.Context, req *connect.Request[identityv1.GetUserByFirebaseUIDRequest]) (*connect.Response[identityv1.User], error) {
	resp, err := a.s.GetUserByFirebaseUID(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) CreateUser(ctx context.Context, req *connect.Request[identityv1.CreateUserRequest]) (*connect.Response[identityv1.User], error) {
	resp, err := a.s.CreateUser(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) UpdateProfile(ctx context.Context, req *connect.Request[identityv1.UpdateProfileRequest]) (*connect.Response[identityv1.User], error) {
	resp, err := a.s.UpdateProfile(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) GetMyProfile(ctx context.Context, req *connect.Request[emptypb.Empty]) (*connect.Response[identityv1.User], error) {
	resp, err := a.s.GetMyProfile(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) CheckPermission(ctx context.Context, req *connect.Request[identityv1.CheckPermissionRequest]) (*connect.Response[identityv1.PermissionDecision], error) {
	resp, err := a.s.CheckPermission(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) RegisterOrganization(ctx context.Context, req *connect.Request[identityv1.RegisterOrganizationRequest]) (*connect.Response[identityv1.RegisterOrganizationResponse], error) {
	resp, err := a.s.RegisterOrganization(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) GetMyOrganization(ctx context.Context, req *connect.Request[emptypb.Empty]) (*connect.Response[identityv1.Organization], error) {
	resp, err := a.s.GetMyOrganization(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) UpdateMyOrganization(ctx context.Context, req *connect.Request[identityv1.UpdateMyOrganizationRequest]) (*connect.Response[identityv1.Organization], error) {
	resp, err := a.s.UpdateMyOrganization(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) InviteTherapist(ctx context.Context, req *connect.Request[identityv1.InviteTherapistRequest]) (*connect.Response[identityv1.Invitation], error) {
	resp, err := a.s.InviteTherapist(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) ListTherapistsInMyOrg(ctx context.Context, req *connect.Request[emptypb.Empty]) (*connect.Response[identityv1.ListTherapistsResponse], error) {
	resp, err := a.s.ListTherapistsInMyOrg(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) RemoveTherapist(ctx context.Context, req *connect.Request[identityv1.RemoveTherapistRequest]) (*connect.Response[emptypb.Empty], error) {
	resp, err := a.s.RemoveTherapist(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) AcceptInvitation(ctx context.Context, req *connect.Request[identityv1.AcceptInvitationRequest]) (*connect.Response[identityv1.AcceptInvitationResponse], error) {
	resp, err := a.s.AcceptInvitation(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) AdminListOrganizations(ctx context.Context, req *connect.Request[identityv1.AdminListOrganizationsRequest]) (*connect.Response[identityv1.AdminListOrganizationsResponse], error) {
	resp, err := a.s.AdminListOrganizations(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) AdminGetOrganization(ctx context.Context, req *connect.Request[identityv1.AdminGetOrganizationRequest]) (*connect.Response[identityv1.OrganizationDetails], error) {
	resp, err := a.s.AdminGetOrganization(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) AdminSetOrganizationStatus(ctx context.Context, req *connect.Request[identityv1.AdminSetOrganizationStatusRequest]) (*connect.Response[emptypb.Empty], error) {
	resp, err := a.s.AdminSetOrganizationStatus(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) AdminUpdateOrganization(ctx context.Context, req *connect.Request[identityv1.AdminUpdateOrganizationRequest]) (*connect.Response[identityv1.Organization], error) {
	resp, err := a.s.AdminUpdateOrganization(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) AdminListUsers(ctx context.Context, req *connect.Request[identityv1.AdminListUsersRequest]) (*connect.Response[identityv1.AdminListUsersResponse], error) {
	resp, err := a.s.AdminListUsers(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) AdminGetUser(ctx context.Context, req *connect.Request[identityv1.AdminGetUserRequest]) (*connect.Response[identityv1.User], error) {
	resp, err := a.s.AdminGetUser(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) AdminUpdateUser(ctx context.Context, req *connect.Request[identityv1.AdminUpdateUserRequest]) (*connect.Response[identityv1.User], error) {
	resp, err := a.s.AdminUpdateUser(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) AdminDeleteUser(ctx context.Context, req *connect.Request[identityv1.AdminDeleteUserRequest]) (*connect.Response[emptypb.Empty], error) {
	resp, err := a.s.AdminDeleteUser(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) GetReportPreferences(ctx context.Context, req *connect.Request[identityv1.GetReportPreferencesRequest]) (*connect.Response[identityv1.ReportPreferences], error) {
	resp, err := a.s.GetReportPreferences(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) UpdateReportPreferences(ctx context.Context, req *connect.Request[identityv1.UpdateReportPreferencesRequest]) (*connect.Response[identityv1.ReportPreferences], error) {
	resp, err := a.s.UpdateReportPreferences(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}

func (a *ConnectAdapter) HealthCheck(ctx context.Context, req *connect.Request[emptypb.Empty]) (*connect.Response[identityv1.HealthCheckResponse], error) {
	resp, err := a.s.HealthCheck(ctx, req.Msg)
	if err != nil {
		return nil, err
	}
	return connect.NewResponse(resp), nil
}
