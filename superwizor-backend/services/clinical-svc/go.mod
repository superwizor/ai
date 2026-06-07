module github.com/superwizor-ai/backend/services/clinical-svc

go 1.26.2

require (
	cloud.google.com/go/kms v1.30.0
	cloud.google.com/go/pubsub/v2 v2.4.0
	github.com/google/uuid v1.6.0
	github.com/jackc/pgerrcode v0.0.0-20250907135507-afb5586c32a6
	github.com/jackc/pgx/v5 v5.9.2
	github.com/pgvector/pgvector-go v0.3.0
	github.com/superwizor-ai/backend/pkg/cors v0.0.0-00010101000000-000000000000
	go.opentelemetry.io/contrib/detectors/gcp v1.43.0
	go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc v0.68.0
	go.opentelemetry.io/otel v1.43.0
	go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc v1.43.0
	go.opentelemetry.io/otel/sdk v1.43.0
	google.golang.org/api v0.282.0
	google.golang.org/grpc v1.81.1
	google.golang.org/protobuf v1.36.11
)

require (
	cloud.google.com/go v0.123.0 // indirect
	cloud.google.com/go/auth v0.20.0 // indirect
	cloud.google.com/go/auth/oauth2adapt v0.2.8 // indirect
	cloud.google.com/go/iam v1.10.0 // indirect
	cloud.google.com/go/longrunning v0.9.0 // indirect
	github.com/felixge/httpsnoop v1.0.4 // indirect
	github.com/golang/groupcache v0.0.0-20241129210726-2c02b8208cf8 // indirect
	github.com/google/s2a-go v0.1.9 // indirect
	github.com/googleapis/enterprise-certificate-proxy v0.3.16 // indirect
	github.com/googleapis/gax-go/v2 v2.22.0 // indirect
	go.einride.tech/aip v0.83.0 // indirect
	go.opencensus.io v0.24.0 // indirect
	go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp v0.67.0 // indirect
	golang.org/x/crypto v0.51.0 // indirect
	golang.org/x/oauth2 v0.36.0 // indirect
	golang.org/x/time v0.15.0 // indirect
	google.golang.org/genproto v0.0.0-20260319201613-d00831a3d3e7 // indirect
)

require (
	cloud.google.com/go/compute/metadata v0.9.0 // indirect
	connectrpc.com/connect v1.20.0
	github.com/GoogleCloudPlatform/opentelemetry-operations-go/detectors/gcp v1.32.0 // indirect
	github.com/cenkalti/backoff/v5 v5.0.3 // indirect
	github.com/cespare/xxhash/v2 v2.3.0 // indirect
	github.com/go-logr/logr v1.4.3 // indirect
	github.com/go-logr/stdr v1.2.2 // indirect
	github.com/grpc-ecosystem/grpc-gateway/v2 v2.28.0 // indirect
	github.com/jackc/pgpassfile v1.0.0 // indirect
	github.com/jackc/pgservicefile v0.0.0-20240606120523-5a60cdf6a761 // indirect
	github.com/jackc/puddle/v2 v2.2.2 // indirect
	github.com/superwizor-ai/backend/gen/go v0.0.0
	github.com/superwizor-ai/backend/pkg/connectmd v0.0.0-00010101000000-000000000000
	github.com/superwizor-ai/backend/pkg/cryptobox v0.0.0-00010101000000-000000000000
	go.opentelemetry.io/auto/sdk v1.2.1 // indirect
	go.opentelemetry.io/otel/exporters/otlp/otlptrace v1.43.0 // indirect
	go.opentelemetry.io/otel/metric v1.43.0 // indirect
	go.opentelemetry.io/otel/trace v1.43.0 // indirect
	go.opentelemetry.io/proto/otlp v1.10.0 // indirect
	golang.org/x/net v0.55.0 // indirect
	golang.org/x/sync v0.20.0 // indirect
	golang.org/x/sys v0.45.0 // indirect
	golang.org/x/text v0.37.0 // indirect
	google.golang.org/genproto/googleapis/api v0.0.0-20260401024825-9d38bb4040a9 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20260523011958-0a33c5d7ca68 // indirect
)

replace github.com/superwizor-ai/backend/gen/go => ../../gen/go

replace github.com/superwizor-ai/backend/pkg/cryptobox => ../../pkg/cryptobox

replace github.com/superwizor-ai/backend/pkg/cors => ../../pkg/cors

replace github.com/superwizor-ai/backend/pkg/connectmd => ../../pkg/connectmd
