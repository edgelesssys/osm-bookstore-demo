package database

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"os"

	"github.com/edgelesssys/ego/marble"
	mysql_driver "github.com/go-sql-driver/mysql"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

// Refer to docs/example/manifests/apps/mysql.yaml for database setup
const (
	dbuser = "bookwarehouse"
	dbport = 3306
	dbname = "booksdemo"
)

// GetMySQLConnection returns a MySQL connection using default configuration
func GetMySQLConnection() (*gorm.DB, error) {
	// Setup TLS for SQL connection
	pem := []byte(os.Getenv(marble.MarbleEnvironmentRootCA))
	rootCertPool := x509.NewCertPool()
	if ok := rootCertPool.AppendCertsFromPEM(pem); !ok {
		panic("failed to append PEM.")
	}

	// Get certificate + private key for bookwarehouse
	cert, err := tls.X509KeyPair([]byte(os.Getenv("SQL_CERT")), []byte(os.Getenv("SQL_KEY")))
	if err != nil {
		panic("failed to create X509KeyPair.")
	}

	// Register SQL TLS config in the MySQL driver
	mysql_driver.RegisterTLSConfig("edgelessdb", &tls.Config{
		RootCAs:      rootCertPool,
		Certificates: []tls.Certificate{cert},
	})

	// Create MySQL connection with the above created TLS configuration
	connStr := fmt.Sprintf("%s@tcp(%s:%d)/%s?tls=%s&charset=utf8mb4&timeout=20s", dbuser, "127.0.0.1", dbport, dbname, "edgelessdb")
	db, err := gorm.Open(mysql.New(mysql.Config{
		DriverName: "mysql",
		DSN:        connStr,
	}), &gorm.Config{})

	return db, err
}
