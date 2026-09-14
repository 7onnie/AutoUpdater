# AutoUpdater #1: Messung 2026-09-13

Push-Probe: 1081cfd, Branch `fix/issue-1-token-rotation-proof`.
Vorhandener Teilfix: 686be0c priorisiert Release-Tokens, übernimmt aber bei leerem
Feld weiterhin den alten Token. Fundstellen vor Änderung:
- lib/auto_update_engine.sh:139-158
- lib/auto_update_github_only.sh:42-61
- lib/auto_update_direct_only.sh:42-61
- standalone/auto_update_standalone.sh:122-141

Aktueller Auftrag verlangt stattdessen eine Laufzeitquelle ohne Carry-Forward.
Die bestehende Shell-Suite ist grün: Modes Total 15 / Passed 16 / Failed 0
(bestehender Zählfehler), Credential-Rotation Total 12 / Passed 12 / Failed 0.
Es existiert bisher keine pytest-Suite, daher keine pytest-Summenzeile und keine
pytest-Skips für den ursprünglichen Stand.

Issue-Kommentar: https://github.com/7onnie/AutoUpdater/issues/1#issuecomment-5652675985

Git meldete Read-only file system für packed-refs.lock und config. Commit und
Remote-Push gelangen im echten Arbeitsbaum; kein Ausweichrepository.
