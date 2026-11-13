# Construire l’IPA à signer

Ce ZIP contient le **prototype source 0.2.0**, pas un IPA compilé.

1. Créer un dépôt GitHub puis y mettre le contenu de `LainCord-iOS` à la racine.
   Conserver le dossier caché `.github`, `tests` et tous les autres fichiers.
2. Ouvrir **Actions → Construire LainCord IPA (non signe) → Run workflow**.
3. Si les vérifications et la compilation réussissent, télécharger l’artefact
   **LainCord-IPA-non-signe** en bas de l’exécution terminée.
4. Extraire `LainCord-unsigned.ipa` du ZIP de l’artefact.
5. Importer cet IPA dans son outil de signature, sélectionner son certificat et
   son profil, puis signer et installer. iOS 17 minimum.

Alternative sur Mac : `bash scripts/build_unsigned_ipa.sh` avec Xcode installé.

La compilation a réussi. La connexion réelle et les appels iPhone restent à valider.
Une signature réussie ne suffit pas à prouver que les appels fonctionnent.
Lire le README pour les limitations et les essais à faire.
