.PHONY: install uninstall check test
install:
	./install.sh
uninstall:
	./uninstall.sh
check:
	python3 -m py_compile bin/llama-modelctl bin/llama-hw-select
	bash -n install.sh uninstall.sh tests/smoke.sh
test: check
	bash tests/smoke.sh
