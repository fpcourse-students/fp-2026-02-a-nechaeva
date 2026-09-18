# Единая точка входа домашки. `make` без цели печатает список целей.
#
# make build                  собрать проект
# make repl                   интерпретатор: GHCi со всеми уровнями (Haskell) или λ-REPL с src/hw.lam
# make repl FILE=путь.lam     λ-REPL с другим файлом, например FILE=lambda-engine/tutorial.lam
# make check                  линтер и тесты всех задач; код выхода — закрыт ли уровень 1
# make check ONLY="1.1 1.2"   то же, но только для перечисленных задач
# make check FILE=путь.lam    проверить другой .lam-файл (без манифеста TASKS), например учебный
# make submit [MSG="…"]       сборка, проверка для сведения, коммит и пуш
# make release MSG="…"        для преподавателей: обновить решения и опубликовать шаблон

ONLY ?=
MSG ?=
FILE ?=

.PHONY: help build repl lint test check submit release

help:
	@sed -n '3,10p' Makefile | sed 's/^# //'

# Собирает только то, что нужно для проверки: библиотеку и тесты домашки.
build:
	cabal build homework-test

# λ-домашку узнаём по src/hw.lam (или по явному FILE). GHCi открывает модуль Repl,
# который импортирует все уровни, поэтому в области видимости сразу вся домашка.
# -v0 прячет служебные сообщения cabal; первая сборка интерпретатора идёт молча.
repl:
	@if [ -n "$(FILE)" ] || [ -f src/hw.lam ]; then \
	  echo "Готовлю интерпретатор λ-термов…"; \
	  cabal build -v0 lambda && cabal run -v0 lambda -- load $(or $(FILE),src/hw.lam); \
	else \
	  cabal repl -v0 homework; \
	fi

# Подсказки линтера не влияют на статус задач, но их видит ревью; `make check` показывает их каждый раз.
# В λ-домашке кода на Haskell у студента нет, и линтер не запускается — ставить hlint не нужно.
lint:
	@if [ -f src/hw.lam ]; then \
	  echo "λ-домашка: линтер Haskell не запускается"; \
	else \
	  hlint src test; \
	fi

# С FILE раннер проверяет указанный .lam-файл вместо src/hw.lam; манифест TASKS
# к нему не относится, поэтому отключается (HASKELL_TASKS указывает на несуществующий файл).
test:
	$(if $(FILE),LAMBDA_FILE=$(FILE) HASKELL_TASKS=/nonexistent) cabal test homework-test --test-options="$(ONLY)"

check:
	-$(MAKE) --no-print-directory lint
	$(MAKE) --no-print-directory test

# Любой пуш в main — текущая версия домашки: её проверяет CI и её же смотрит ревью.
# Проверка запускается для сведения, блокирует только несобирающийся код.
# Перед пушем подтягиваются правки, которые преподаватели вносят в репозиторий
# (исправления тестов, прелюдии, проверялки): ваши решения они не трогают.
submit: build
	-$(MAKE) --no-print-directory check
	git add -A
	git commit -m "$(or $(MSG),Сдача)" --allow-empty
	git pull --rebase --quiet origin main
	git push origin main
	@echo "Отчёт CI появится в вашем pull request."

# Для преподавателей. main — версия для студентов, solutions — эталон; решения в main не вливаются,
# ветка solutions только проверяется строгим прогоном и пушится в origin. Ожидает remote origin
# (репозиторий домашки), remote template (внутренний шаблон) и remote public (шаблон в организации студентов).
release:
	git config pull.rebase false
	git pull template main --no-edit
	$(MAKE) --no-print-directory lint
	cabal build all --ghc-options=-Werror
	git push origin main:main
	git push public main:main
	git checkout solutions
	$(MAKE) --no-print-directory lint
	HASKELL_TEST_STRICT=1 $(MAKE) --no-print-directory test
	git commit -am "[no ci] $(or $(MSG),Update)" --allow-empty
	git push origin solutions:solutions
	git checkout main
