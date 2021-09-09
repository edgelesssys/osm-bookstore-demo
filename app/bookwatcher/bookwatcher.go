package main

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"time"

	"github.com/edgelesssys/osm-bookstore-demo/app/common"
)

const (
	bookBuyerPort   = 8080
	bookStoreV1Port = 8084
	bookStoreV2Port = 8082
	bookThiefPort   = 8083
)

var (
	client   *http.Client
	certFile = flag.String("c", "marblerun.crt", "CA certificate to use as a root of trust")
)

func clearScreen() {
	fmt.Print("\033[H\033[2J")
}

func printGreenln(msg string) {
	fmt.Printf("\033[32m%s\033[0m\n", msg)
}

func printYellowln(msg string) {
	fmt.Printf("\033[33m%s\033[0m\n", msg)
}

func printRedln(msg string) {
	fmt.Printf("\033[31m%s\033[0m\n", msg)
}

func getBookData(dest interface{}, port int, errc chan<- error) {

	resp, err := client.Get(fmt.Sprintf("https://localhost:%d/raw", port))
	if err != nil {
		errc <- fmt.Errorf("error fetching data (port %d): %v", port, err)
		return
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			errc <- fmt.Errorf("error closing response (port %d): %v", port, err)
		}
	}()

	output, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		errc <- fmt.Errorf("error reading data (port %d): %v", port, err)
		return
	}

	err = json.Unmarshal(output, dest)
	if err != nil {
		errc <- fmt.Errorf("error unmarshalling data (port %d): %v", port, err)
	}
	errc <- nil
}

func main() {
	flag.Parse()
	raw, err := ioutil.ReadFile(*certFile)
	if err != nil {
		log.Fatal(err)
	}

	var certs []*pem.Block
	block, rest := pem.Decode(raw)
	if block == nil {
		log.Fatal("could not parse certificate")
	}
	certs = append(certs, block)
	for len(rest) > 0 {
		block, rest = pem.Decode([]byte(rest))
		if block == nil {
			log.Fatal("could not parse certificate chain")
		}
		certs = append(certs, block)
	}
	certPool := x509.NewCertPool()
	if ok := certPool.AppendCertsFromPEM(pem.EncodeToMemory(certs[len(certs)-1])); !ok {
		log.Fatal("failed to parse certificate")
	}
	if len(certs) > 1 {
		if ok := certPool.AppendCertsFromPEM(pem.EncodeToMemory(certs[0])); !ok {
			log.Fatal("failed to parse certificate")
		}
	}
	client = &http.Client{
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				RootCAs: certPool,
			},
		},
	}

	bookBuyerPurchases := &common.BookBuyerPurchases{}
	bookThiefThievery := &common.BookThiefThievery{}
	bookStorePurchasesV1 := &common.BookStorePurchases{}
	bookStorePurchasesV2 := &common.BookStorePurchases{}

	for {
		errc := make(chan error, 4)

		bookBuyerPurchasesTemp := *bookBuyerPurchases
		go getBookData(bookBuyerPurchases, bookBuyerPort, errc)

		bookThiefThieveryTemp := *bookThiefThievery
		go getBookData(bookThiefThievery, bookThiefPort, errc)

		bookStorePurchasesV1Temp := *bookStorePurchasesV1
		go getBookData(bookStorePurchasesV1, bookStoreV1Port, errc)

		bookStorePurchasesV2Temp := *bookStorePurchasesV2
		go getBookData(bookStorePurchasesV2, bookStoreV2Port, errc)

		var errs []error
		for i := 0; i < 4; i++ {
			errs = append(errs, <-errc)
		}

		bookBuyerHasChanged := (bookBuyerPurchases.BooksBought-bookBuyerPurchasesTemp.BooksBought) != 0 ||
			(bookBuyerPurchases.BooksBoughtV1-bookBuyerPurchasesTemp.BooksBoughtV1) != 0 ||
			(bookBuyerPurchases.BooksBoughtV2-bookBuyerPurchasesTemp.BooksBoughtV2) != 0

		bookThiefHasChanged := (bookThiefThievery.BooksStolen-bookThiefThieveryTemp.BooksStolen) != 0 ||
			(bookThiefThievery.BooksStolenV1-bookThiefThieveryTemp.BooksStolenV1) != 0 ||
			(bookThiefThievery.BooksStolenV2-bookThiefThieveryTemp.BooksStolenV2) != 0

		bookStoreV1HasChanged := (bookStorePurchasesV1.BooksSold - bookStorePurchasesV1Temp.BooksSold) != 0
		bookStoreV2HasChanged := (bookStorePurchasesV2.BooksSold - bookStorePurchasesV2Temp.BooksSold) != 0

		clearScreen()
		for _, err := range errs {
			if err != nil {
				log.Println(err)
			}
		}
		printFunc := printYellowln
		if bookBuyerHasChanged {
			printFunc = printGreenln
		}
		printFunc(fmt.Sprintf(
			"bookbuyer     Books bought: %d  V1 books bought: %d  V2 books bought: %d",
			bookBuyerPurchases.BooksBought,
			bookBuyerPurchases.BooksBoughtV1,
			bookBuyerPurchases.BooksBoughtV2,
		))

		printFunc = printYellowln
		if bookThiefHasChanged {
			printFunc = printRedln
		}
		printFunc(fmt.Sprintf(
			"bookthief     Books stolen: %d  V1 books stolen: %d  V2 books stolen: %d",
			bookThiefThievery.BooksStolen,
			bookThiefThievery.BooksStolenV1,
			bookThiefThievery.BooksStolenV2,
		))

		printFunc = printYellowln
		if bookStoreV1HasChanged {
			printFunc = printGreenln
		}
		printFunc(fmt.Sprintf("bookstore v1  Books sold: %d", bookStorePurchasesV1.BooksSold))

		printFunc = printYellowln
		if bookStoreV2HasChanged {
			printFunc = printGreenln
		}
		printFunc(fmt.Sprintf("bookstore v2  Books sold: %d", bookStorePurchasesV2.BooksSold))

		time.Sleep(1 * time.Second)
	}
}
