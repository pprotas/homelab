FROM arm64v8/alpine:3.21

ARG VERSION=0.9.1

RUN apk add --no-cache wget ca-certificates \
    && wget -q "https://github.com/academo/grafana-alerting-ntfy-webhook-integration/releases/download/${VERSION}/grafana-ntfy-${VERSION}-linux-arm64.tar.gz" -O /tmp/grafana-ntfy.tar.gz \
    && tar -xzf /tmp/grafana-ntfy.tar.gz -C /usr/local/bin \
    && chmod +x /usr/local/bin/grafana-ntfy \
    && rm /tmp/grafana-ntfy.tar.gz \
    && apk del wget

EXPOSE 8080

ENTRYPOINT ["grafana-ntfy"]
