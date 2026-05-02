package main

import (
	"fmt"
	"net/url"
)

func main() {
	raw := "identity-svc-qcmcx-ew.a.run.app"
	u, _ := url.Parse(raw)
	fmt.Printf("raw: %s\nHost: '%s'\nPath: '%s'\n", raw, u.Host, u.Path)
}
