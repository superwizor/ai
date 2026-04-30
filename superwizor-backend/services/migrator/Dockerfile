FROM migrate/migrate:v4.17.0 AS migrate

FROM alpine:3.19
RUN apk add --no-cache python3
COPY --from=migrate /migrate /usr/local/bin/migrate

COPY migrations /migrations
COPY services/migrator/run.sh /run.sh
RUN chmod +x /run.sh

ENTRYPOINT ["/run.sh"]
