package common

import (
	"crypto/tls"
	"fmt"
	"net/http"
	"os"

	"github.com/gorilla/mux"
)

// ListenAndServeTLS loads certificate and key from environement and starts a TLS server
func ListenAndServeTLS(port int, handler *mux.Router) {
	cert, err := tls.X509KeyPair([]byte(os.Getenv("WEB_CERT")), []byte(os.Getenv("WEB_KEY")))
	if err != nil {
		log.Fatal().Err(err).Msgf("Failed to load TLS certificate and key pair: %v", err)
	}
	server := http.Server{
		Addr: fmt.Sprintf(":%d", port),
		TLSConfig: &tls.Config{
			Certificates: []tls.Certificate{cert},
		},
	}

	if err := server.ListenAndServeTLS("", ""); err != nil {
		log.Fatal().Err(err).Msgf("Failed to start HTTP server on port %d", port)
	}
}
