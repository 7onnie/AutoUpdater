# Runtime-Quelle für GitHub-Tokens

Die vier Shell-Updater übernehmen keine Tokens mehr aus Version A. Literale
`GITHUB_TOKEN=`-Zuweisungen in Version B werden beim Update durch eine
Laufzeitabfrage ersetzt. Bereits ausgelieferte dynamische Ausdrücke bleiben
unverändert (z. B. Keychain-Abfragen).

Für zentral rotierbare Credentials wird `GITHUB_TOKEN_FILE` in der
Startumgebung konfiguriert: absoluter Pfad zu einer durch die vorhandene
Verwaltung aktualisierten Datei oder zu einer Datei auf einem eingebundenen
Share. Inhalt: nur der Token, optional mit abschließendem Zeilenumbruch.
Die Datei wird bei jedem Scriptstart neu gelesen. Eine Änderung der zentralen
Quelle wirkt damit beim nächsten Start ohne erneutes Script-Update und ohne
Handarbeit auf den bereits konfigurierten Maschinen.

Ohne Dateiquelle wird `GITHUB_TOKEN` aus der Startumgebung verwendet. Ein
konfigurierter, nicht lesbarer Dateipfad führt zum Abbruch; es gibt dann keinen
stillen Rückfall auf einen veralteten Umgebungstoken. Ein leeres Token-File
bedeutet explizit einen leeren Token (z. B. für öffentliche Repositories).

Die Bereitstellung und Aktualisierung der Quelle gehört zur vorhandenen
Flottenkonfiguration. Dieser Branch richtet keine Quelle auf Maschinen ein.
Maschinen, die bisher ausschließlich einen hardcodierten Token haben, brauchen
bei der Einführung diese Konfiguration; der alte Token wird bewusst nicht
weiterkopiert. Ein bereits ungültiger Token kann außerdem den Download des
neuen Updaters nicht authentifizieren. Die Update-Engine und ihre Download-,
Backup- und Austauschverfahren bleiben unverändert.
