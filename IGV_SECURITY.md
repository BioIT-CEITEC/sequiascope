# IGV Snapshot Architecture - Security Design

## 🔒 Bezpečnostní architektura

Tato aplikace používá **watcher-based architecture** pro generování IGV snapshotů místo přímého přístupu k Docker API. Tento design je zvolen **záměrně z bezpečnostních důvodů**.

### Proč NE Docker socket mounting?

❌ **NEBEZPEČNÉ** (původní návrh):
```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock  # SECURITY RISK!
```

**Bezpečnostní rizika:**
1. **Root access k host systému** - Kdokoliv s přístupem k Docker socketu má prakticky root přístup
2. **Container escape** - Možnost vytvářet privilegované kontejnery a přistupovat k host systému
3. **Data breach** - Přístup k datům jiných kontejnerů a host filesystému
4. **Compliance issues** - Neprůchozí pro healthcare/research security audity

### ✅ Bezpečné řešení: Watcher Architecture

**Architektura:**
```
┌─────────────────┐         Shared Volume        ┌─────────────────┐
│  Shiny Container│    (pouze filesystem I/O)    │  IGV Container  │
│                 │                               │                 │
│  1. Vytvoří     │─────── batch_file.txt ──────>│  Watcher:       │
│     batch file  │                               │  - Sleduje nové │
│                 │                               │    batch files  │
│  2. Čeká na     │<────── batch_file.done ──────│  - Spustí IGV   │
│     .done file  │                               │  - Vytvoří .done│
└─────────────────┘                               └─────────────────┘
```

**Komunikace:**
- ✅ Pouze přes shared filesystem (read/write soubory)
- ✅ Žádný přístup k Docker API
- ✅ Žádné privilegované operace
- ✅ Úplná izolace kontejnerů

**Bezpečnostní výhody:**
1. **Principle of Least Privilege** - Kontejnery mají pouze oprávnění, která potřebují
2. **Container Isolation** - Žádný kontejner nemá kontrolu nad jinými kontejnery
3. **Audit Trail** - Všechny operace logované, batch files archivované
4. **Fail-safe** - Pokud watcher selže, pouze IGV snapshoty nefungují, ne celá aplikace

## 📁 Implementace

### Shiny Container (R/Shiny aplikace)
- **Role:** Vytváří IGV batch files
- **Oprávnění:** Read/write do shared volume
- **Komunikace:** Pouze filesystem
- **Bezpečnost:** Žádný přístup k Docker nebo host systému

```r
# Vytvoř batch file
createIGVBatchFile(...)

# Čekej na completion (polling .done file)
runIGVSnapshotParallel(batch_file, timeout = 300)
```

### IGV Container (Java/IGV Desktop)
- **Role:** Spouští IGV Desktop pro snapshoty
- **Oprávnění:** Read/write do shared volume, spouštění IGV
- **Komunikace:** Pouze filesystem
- **Bezpečnost:** Žádný přístup k jiným kontejnerům

```bash
# Watcher běží jako hlavní proces
/usr/local/bin/igv_batch_watcher.sh

# Sleduje: /srv/igv-static/igv_snapshots/*_batch.txt
# Vytváří: *_batch.txt.done nebo *_batch.txt.error
```

### Shared Volume
```yaml
volumes:
  igv-shared:
    # Sdílený mezi kontejnery
    # Obsahuje: batch files, snapshoty, status files
    # Žádné privilegované nebo citlivé soubory
```

## 🏥 Healthcare/Research Compliance

Tato architektura je navržena pro použití v:
- ✅ Secured Kubernetes clusters
- ✅ Healthcare institutional environments (HIPAA, GDPR)
- ✅ Research institutions s citlivými daty
- ✅ Multi-tenant environments

**Bezpečnostní certifikace:**
- Žádný Docker socket mounting
- Žádné privilegované kontejnery
- Žádný přístup k host systému
- Úplná containerizace a izolace

## 🔍 Monitoring & Debugging

**Log locations:**
```bash
# Shiny logs (R aplikace)
docker compose logs shiny

# IGV watcher logs
docker compose logs igv-static

# Batch files a status
docker compose exec igv-static ls -la /srv/igv-static/igv_snapshots/
```

**Status files:**
- `*_batch.txt` - IGV batch script
- `*_batch.txt.done` - Success marker
- `*_batch.txt.error` - Error marker with error message
- `*_batch.txt.log` - IGV execution log

## 📊 Performance

**Paralelní zpracování:**
- Shiny: Spouští futures pro každého pacienta paralelně
- IGV Watcher: Zpracovává batch files s vlastním Xvfb pro každý
- Display numbers: Automaticky 100-150 (prevence konfliktů)

**Timeouts:**
- Default: 300 sekund (5 minut) per patient
- Konfigurovatelné v `runIGVSnapshotParallel(timeout_seconds = 300)`

## 🔄 Troubleshooting

**Pokud snapshoty nefungují:**

1. **Zkontrolovat watcher logs:**
   ```bash
   docker compose logs igv-static | grep WATCHER
   ```

2. **Zkontrolovat batch files:**
   ```bash
   docker compose exec igv-static ls -la /srv/igv-static/igv_snapshots/*/
   ```

3. **Manuální test:**
   ```bash
   docker compose exec igv-static bash
   cd /srv/igv-static/igv_snapshots/PATIENT_ID/
   cat PATIENT_ID_batch.txt
   ```

4. **Restart watcheru:**
   ```bash
   docker compose restart igv-static
   ```

## 📝 Poznámky pro vývojáře

Pokud budete chtít změnit architekturu zpět na Docker socket mounting:
1. **NEZAPOMEŇTE** na bezpečnostní rizika
2. **INFORMUJTE** security tým
3. **ZDOKUMENTUJTE** proč je to nutné
4. **IMPLEMENTUJTE** dodatečná bezpečnostní opatření (SELinux, AppArmor, network policies)

**Doporučení: Zachovat watcher architecture pro production use!** 🔒
