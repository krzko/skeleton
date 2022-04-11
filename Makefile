VERSION = $$(git describe --abbrev=0 --tags)
COMMIT_TAG = $$(git tag --points-at HEAD)
VERSION_DATE = $$(git log -1 --pretty='%ad' --date=format:'%Y-%m-%d' $(VERSION))
COMMIT_REV = $$(git rev-list -n 1 $(VERSION))
MAINTAINER = "Kristof Kowalski"

all: build

version:
	@echo $(VERSION)

commit_rev:
	@echo $(COMMIT_REV)

start:
	go run main.go

deps-clean:
	go clean -modcache
	rm -rf vendor

deps-download:
	GO111MODULE=on go mod download
	GO111MODULE=on go mod vendor

deps: deps-clean deps-download
vendor: deps

debug:
	DEBUG=1 go run main.go

.PHONY: build
build:
	go build -ldflags "-X github.com/krzko/skeleton/skeleton.version=$(VERSION)" -o bin/skeleton main.go

# http://macappstore.org/upx
build-mac: clean-mac
	env GOARCH=amd64 go build -ldflags "-s -w -X github.com/krzko/skeleton/skeleton.version=$(VERSION)" -o bin/macos/skeleton && upx bin/macos/skeleton

build-linux: clean-linux
	env GOOS=linux GOARCH=amd64 go build -ldflags "-s -w -X github.com/krzko/skeleton/skeleton.version=$(VERSION)" -o bin/linux/skeleton && upx bin/linux/skeleton

build-multiple: clean
	env GOARCH=amd64 go build -ldflags "-s -w -X github.com/krzko/skeleton/skeleton.version=$(VERSION)" -o bin/skeleton64 && upx bin/skeleton64 && \
	env GOARCH=386 go build -ldflags "-s -w -X github.com/krzko/skeleton/skeleton.version=$(VERSION)" -o bin/skeleton32 && upx bin/skeleton32

install: build
	sudo mv bin/skeleton /usr/local/bin

uninstall:
	sudo rm /usr/local/bin/skeleton

clean-mac:
	go clean && \
	rm -rf bin/mac

clean-linux:
	go clean && \
	rm -rf bin/linux

clean:
	go clean && \
	rm -rf bin/

.PHONY: docs
docs:
	(cd docs && hugo)

docs-server:
	(cd docs && hugo serve -p 8080)

docs-deploy: docs
	netlify deploy --prod

docs-open:
	xdg-open "http://localhost:8080"

test:
	go test ./...

skeleton-test:
	go run main.go -test

skeleton-version:
	go run main.go -version

skeleton-clean:
	go run main.go -clean

skeleton-reset:
	go run main.go -reset

snap-clean:
	snapcraft clean
	rm -f skeleton_*.snap
	rm -f skeleton_*.tar.bz2

snap-stage:
	# https://github.com/elopio/go/issues/2
	mv go.mod go.mod~ ;GO111MODULE=off GOFLAGS="-ldflags=-s -ldflags=-w -ldflags=-X=github.com/krzko/skeleton/skeleton.version=$(VERSION)" snapcraft stage; mv go.mod~ go.mod

snap-install:
	sudo apt install snapd
	sudo snap install snapcraft --classic
	sudo snap install core20

snap-install-arch:
	yay -S snapd
	sudo snap install snapcraft --classic
	sudo ln -s /var/lib/snapd/snap /snap # enable classic snap support
	sudo snap install hello-world

snap-install-local:
	sudo snap install --dangerous skeleton_master_amd64.snap

snap-build: snap-clean snap-stage
	snapcraft snap

snap-deploy:
	snapcraft push skeleton_*.snap --release stable

snap-remove:
	snap remove skeleton

snap-build-and-deploy: snap-build snap-deploy snap-clean
	@echo "done"

snap: snap-build-and-deploy

flatpak-build:
	flatpak-builder --force-clean build-dir com.github.krzko.skeleton.json

flatpak-run-test:
	flatpak-builder --run build-dir com.github.krzko.skeleton.json skeleton

flatpak-repo:
	flatpak-builder --repo=repo --force-clean build-dir com.github.krzko.skeleton.json

flatpak-add-repo:
	flatpak --user remote-add --no-gpg-verify skeleton-repo repo

flatpak-add-flathub:
	sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

flatpak-remove:
	flatpak --user remote-delete skeleton-repo

flatpak-install:
	flatpak --user install skeleton-repo com.github.krzko.skeleton

flatpak-install-local:
	flatpak-builder --force-clean --install --install-deps-from=flathub --user build-dir com.github.krzko.skeleton.json

flatpak-run:
	flatpak run com.github.krzko.skeleton

flatpak-update-version:
	xmlstarlet ed --inplace -u '/component/releases/release/@version' -v $(VERSION) .flathub/com.github.krzko.skeleton.appdata.xml
	xmlstarlet ed --inplace -u '/component/releases/release/@date' -v $(VERSION_DATE) .flathub/com.github.krzko.skeleton.appdata.xml

rpm-install-deps:
	sudo dnf install -y rpm-build
	sudo dnf install -y dnf-plugins-core

rpm-cp-specs:
	cp .rpm/skeleton.spec ~/rpmbuild/SPECS/

rpm-build:
	rpmbuild --nodeps -ba ~/rpmbuild/SPECS/skeleton.spec

rpm-lint:
	rpmlint ~/rpmbuild/SPECS/skeleton.spec

rpm-dirs:
	mkdir -p ~/rpmbuild
	mkdir -p ~/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
	chmod -R a+rwx ~/rpmbuild

rpm-download:
	wget https://github.com/krzko/skeleton/archive/$(VERSION).tar.gz -O ~/rpmbuild/SOURCES/$(VERSION).tar.gz

copr-install-cli:
	sudo dnf install -y copr-cli

copr-deps: copr-install-cli rpm-install-deps

copr-create-project:
	copr-cli create skeleton --chroot fedora-rawhide-x86_64

copr-build:
	copr-cli build skeleton ~/rpmbuild/SRPMS/skeleton-*.rpm
	rm -rf ~/rpmbuild/SRPMS/skeleton-*.rpm

.PHONY: copr
copr: rpm-dirs rpm-cp-specs rpm-download rpm-build copr-build

brew-clean: brew-remove
	brew cleanup --force skeleton
	brew prune

brew-remove:
	brew uninstall --force skeleton

brew-build: brew-remove
	brew install --build-from-source skeleton.rb

brew-audit:
	brew audit --strict skeleton.rb

brew-test:
	brew test skeleton.rb

brew-tap:
	brew tap skeleton/skeleton https://github.com/krzko/skeleton

brew-untap:
	brew untap skeleton/skeleton

git-rm-large:
	java -jar bfg.jar --strip-blobs-bigger-than 200K .

git-repack:
	git reflog expire --expire=now --all
	git fsck --full --unreachable
	git repack -A -d
	git gc --aggressive --prune=now

release:
	rm -rf dist
	VERSION=$(VERSION) goreleaser

docker-login:
	docker login

docker-login-ci:
	docker login -u $(DOCKER_USER) -p $(DOCKER_PASS)

docker-build:
	docker build --build-arg VERSION=$(VERSION) --build-arg MAINTAINER=$(MAINTAINER) -t skeleton/skeleton .

docker-tag:
	docker tag skeleton/skeleton:latest skeleton/skeleton:$(VERSION)

docker-tag-ci:
	docker tag skeleton/skeleton:latest skeleton/skeleton:$(CIRCLE_SHA1)
	docker tag skeleton/skeleton:latest skeleton/skeleton:$(CIRCLE_BRANCH)
	test $(COMMIT_TAG) && docker tag skeleton/skeleton:latest skeleton/skeleton:$(COMMIT_TAG); true

docker-run:
	docker run -it skeleton/skeleton

docker-push:
	docker push skeleton/skeleton:$(VERSION)
	docker push skeleton/skeleton:latest

docker-push-ci:
	docker push skeleton/skeleton:$(CIRCLE_SHA1)
	docker push skeleton/skeleton:$(CIRCLE_BRANCH)
	test $(COMMIT_TAG) && docker push skeleton/skeleton:$(COMMIT_TAG); true
	test $(CIRCLE_BRANCH) == "master" && docker push skeleton/skeleton:latest; true

docker-build-and-push: docker-build docker-tag docker-push

docker-run-ssh:
	docker run -p 2222:22 -v ~/.ssh/demo:/keys -v ~/.cache/skeleton:/tmp/skeleton_config --entrypoint skeleton -it skeleton/skeleton server -k /keys/id_rsa

ssh-server:
	go run cmd/skeleton/skeleton.go server -p 2222

ssh-client:
	ssh localhost -p 2222

mp3:
	cat <(printf "package notifier\nfunc Mp3() string {\nreturn \`" "") <(xxd -p media/notification.mp3 | tr -d "\n") <(printf "\`\n}" "") > pkg/notifier/mp3.go

pkg2appimage-install:
	wget -c https://github.com/$(wget -q https://github.com/AppImage/pkg2appimage/releases -O - | grep "pkg2appimage-.*-x86_64.AppImage" | head -n 1 | cut -d '"' -f 2)
	chmod +x pkg2appimage-*.AppImage

appimage-clean-workspace:
	rm -rf .appimage_workspace

appimage-clean: appimage-clean-workspace
	rm -rf *.AppImage

.PHONY: appimage
appimage: appimage-clean-workspace
	( \
		mkdir -p .appimage_workspace && \
		mkdir -p dist/appimage && \
		cd .appimage_workspace && \
		../pkg2appimage-*.AppImage ../.appimage/skeleton.yml && \
		cp out/skeleton-*.AppImage ../dist/appimage/ \
	)

appimage-run:
	./dist/appimage/skeleton-*.AppImage
