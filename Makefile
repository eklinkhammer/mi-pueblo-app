.PHONY: check check-backend check-mobile dialyzer setup

check: check-backend check-mobile

check-backend:
	cd fence && mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict && mix sobelow --config && mix deps.audit --ignore-package-names hackney && mix test

check-mobile:
	cd mobile && /Users/eklinkhammer/development/flutter/bin/flutter analyze --fatal-infos --fatal-warnings && /Users/eklinkhammer/development/flutter/bin/flutter test

dialyzer:
	cd fence && mix dialyzer

setup:
	cd fence && mix deps.get
	cd mobile && /Users/eklinkhammer/development/flutter/bin/flutter pub get
