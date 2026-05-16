# Paperless API Compatibility

The app supports paperless-ngx v2 and v3 by negotiating the API version from
the server response header.

- paperless-ngx v2 uses API 9.
- paperless-ngx v3 uses API 10.
- If a future server advertises a newer API, the client records that value but
  caps requests at the latest version implemented by the app.

`LocalUserAccount.serverApiVersion` stores the raw server-advertised version.
`LocalUserAccount.apiVersion` stores the version the app should request.
`ApiVersionInterceptor` is the only place that writes those values from server
headers and the only place that adds the `Accept: application/json; version=...`
request header.

Per-request overrides should use `paperlessApiVersionExtra`. The interceptor
still clamps the override, so a stale API 9 request cannot be sent to an API 10
server.

AI features are first-class only when the negotiated API version is 10 or newer
and `/api/ui_settings/` reports AI as enabled. v2 servers and v3 servers without
AI enabled hide the AI UI instead of showing disabled controls.
