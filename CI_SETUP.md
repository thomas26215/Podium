# CI/CD Android : build + release GitHub

À chaque push sur `main`, à chaque tag `v*` ou en lancement manuel, le workflow
[`.github/workflows/build-and-release.yml`](.github/workflows/build-and-release.yml) fait
exactement ce que tu ferais depuis ton terminal :

```bash
flutter pub get && flutter analyze && flutter test
flutter build apk --release                                  # signé avec ton keystore
gh release create v1.0.0 podium-v1.0.0-build1.apk --notes "…"
```

1. installe Flutter **3.44.8** (stable) et Java 17 ;
2. lance `flutter analyze` (échoue uniquement sur les *erreurs*) et `flutter test` ;
3. construit l’APK release signé avec ton keystore (restauré depuis les GitHub Secrets) ;
4. publie une **release GitHub** avec l’APK en pièce jointe et un changelog tiré des commits.

Projet : package `app.podium.games`, version actuelle `1.0.0+1` (`pubspec.yaml`).

## Quelle release est créée ?

| Déclencheur | Release |
|---|---|
| Push sur `main` | La pré-version **`dev`** (APK de développement), **remplacée** à chaque push (son tag suit le dernier commit). |
| Push d’un tag `v1.0.1` | Release de version `v1.0.1` sur ce tag : APK + AAB + prompt des notes Play Store. |
| Lancement manuel (onglet *Actions* → *Run workflow*) | Release de version `v<version du pubspec>` sur le commit choisi (ou `v1.0.1-build3` si `v1.0.1` existe déjà) : APK + AAB ; le champ « Notes de version » remplace le changelog. |

Les releases de version (`v*`) ne sont **jamais modifiées** par les pushes sur `main` : chacune garde l’APK, l’AAB et
le prompt de la version envoyée au Play Store. Relancer le workflow sur un même tag remplace seulement ses fichiers.

Augmente aussi le numéro de build (`+2`) à chaque version : Android refuse d’installer un APK dont le
`versionCode` est inférieur à celui déjà installé.

## AAB pour le Play Store

Sur un **tag `v*`** ou un **lancement manuel**, le workflow construit aussi l’AAB (`flutter build appbundle --release`)
et le joint à la release (`podium-v1.0.1-build3.aab`), à envoyer toi-même dans la Play Console.

Avant de le construire, il vérifie que le numéro de build (le `+3` de `version: 1.0.1+3`) est **strictement supérieur**
à celui de tous les AAB déjà générés — sinon Google Play refuserait l’envoi. S’il n’y en a jamais eu, c’est accepté.
Chaque AAB généré est enregistré par un tag Git `aab/<numéro de build>` (ex. `aab/3`) : ne les supprime pas.

Si ton premier envoi sur le Play Store a été fait à la main (hors CI), crée le tag correspondant une fois pour toutes,
pour que la CI en tienne compte : `git tag aab/1 && git push origin aab/1` (avec le numéro de build envoyé).

Les pushes sur `main` ne construisent pas d’AAB et ne consomment donc aucun numéro de build.

**Notes de mise à jour** : avec l’AAB, la CI prépare un prompt pour Claude qui liste les commits depuis le dernier AAB
(tag `aab/*`) et demande une note au format de la Play Console (`<fr-FR>…</fr-FR>`, 500 caractères maximum, balises non comprises). Il est
affiché dans le résumé du run (onglet *Actions*) et dans la release GitHub : copie-le dans Claude, puis colle sa
réponse dans le champ « Notes de version » de la Play Console.

---

## 1. Keystore

Tu en as déjà un : `android/app/upload-keystore.jks`, référencé par ton `android/key.properties` local
(ignorés par git tous les deux). Sauvegarde-les avec leurs mots de passe : perdre la clé empêche de publier des
mises à jour sur le Play Store.

Nouvelle machine : copie `android/key.properties.example` en `android/key.properties` et remplis-le
(`storeFile` est relatif à `android/app/`). Sans `key.properties`, les builds release locaux sont signés avec
la clé de debug.

## 2. Secrets GitHub (4)

Depuis la racine du projet (CLI GitHub connectée : `gh auth status`) :

```bash
base64 -w 0 android/app/upload-keystore.jks > keystore.jks.base64
gh secret set ANDROID_KEYSTORE_BASE64 < keystore.jks.base64
gh secret set ANDROID_KEYSTORE_PASSWORD --body "$(grep '^storePassword=' android/key.properties | cut -d= -f2-)"
gh secret set ANDROID_KEY_ALIAS         --body "$(grep '^keyAlias='      android/key.properties | cut -d= -f2-)"
gh secret set ANDROID_KEY_PASSWORD      --body "$(grep '^keyPassword='   android/key.properties | cut -d= -f2-)"
gh secret list
rm keystore.jks.base64
```

Ou à la main : GitHub → dépôt **Podium** → **Settings → Secrets and variables → Actions → New repository secret**.

| Nom du secret | Valeur |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `android/app/upload-keystore.jks` encodé en base64 (une seule ligne) |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword` de `android/key.properties` |
| `ANDROID_KEY_ALIAS` | `keyAlias` de `android/key.properties` |
| `ANDROID_KEY_PASSWORD` | `keyPassword` de `android/key.properties` |

La publication de la release utilise le jeton `GITHUB_TOKEN` fourni automatiquement.

## 3. Autoriser le workflow à publier

GitHub → dépôt **Podium** → **Settings → Actions → General → Workflow permissions** → **Read and write
permissions** → **Save**.

## 4. Installer la release sur ton téléphone

1. Sur le téléphone : `https://github.com/thomas26215/Podium/releases` (connecté à GitHub si le dépôt est privé).
2. Release **`dev`** (dernier push sur `main`) ou une release de version `v…` → **Assets** → `podium-….apk` →
   télécharger, puis ouvrir le fichier.
3. La première fois, autorise l’**installation d’applications inconnues** pour ton navigateur.

**Notifications** : app **GitHub** (Play Store) → dépôt Podium → **Watch → Custom → Releases**.

## Dépannage

| Symptôme | Cause / solution |
|---|---|
| Échec à « Vérifier les secrets » | Un des 4 secrets manque ou est mal nommé. |
| Échec à `flutter analyze` | Une *erreur* d’analyse (les infos et warnings ne bloquent pas) : `flutter analyze --no-fatal-infos --no-fatal-warnings` en local. |
| Échec à `flutter test` | `flutter test` en local. |
| « Keystore was tampered with, or password was incorrect » | `ANDROID_KEYSTORE_PASSWORD` incorrect ou base64 cassé. |
| « Cannot recover key » | `ANDROID_KEY_PASSWORD` ou `ANDROID_KEY_ALIAS` incorrect. |
| Échec à « Publier la release » (403) | Étape 3 non faite. |
| « App non installée » | `versionCode` inférieur à celui installé, ou app installée signée avec une autre clé. |
| « Numéro de build … ≤ … (dernier AAB généré) » | Augmente le `+N` de `version:` dans `pubspec.yaml` au-delà du numéro indiqué. |

Si le dépôt est **public**, les releases (et donc l’APK) sont téléchargeables par tout le monde.
