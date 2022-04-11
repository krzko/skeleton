make:
	go run main.go

test:
	go test ./... -short

build:
	go build -o skeleton main.go

install:
	go install