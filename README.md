# LainCord iOS — prototype 0.2.0

Cette version ajoute une connexion Discord au projet de studio audio iOS fourni.
C’est un **prototype basé sur le client web Discord**, et non un portage des
modules Electron de LeanCord Windows. Projet indépendant, ni affilié ni approuvé
par Discord ou les développeurs de LeanCord.

## Implémentation

- Onglet Discord, connexion classique sur discord.com ou saisie masquée du token.
- Vérification du token auprès de `https://discord.com/api/v10/users/@me`.
- Client web Discord dans WKWebView, avec une identité de navigateur de bureau,
  pour accéder aux serveurs, salons et messages de l’interface web.
- Permissions microphone/caméra demandées par iOS pour Discord uniquement.
- Rechargement, erreurs réseau et déconnexion avec effacement de la session.
- Session web temporaire : aucun token dans UserDefaults, fichiers ou logs.
  Les données de session ne sont pas conservées entre deux lancements du processus.
- Arrêt du monitoring du studio à l’ouverture de Discord pour libérer le micro.
- Studio EQ/effets et soundboard local existants.

Le token est vérifié directement auprès de Discord avec une URLSession éphémère
qui refuse les redirections. Un script limité au document principal de
`https://discord.com` initialise la session web. Le code n’envoie aucun secret à
leancord.xyz ni à un service tiers ajouté par ce projet. Le client web Discord
et ses propres intégrations conservent leur comportement habituel.

## État réel de validation

Les quatre tests JavaScript passent. Les compilations Xcode pour le simulateur
et pour iPhone ont réussi sur macOS via GitHub Actions le 13 novembre 2026.
L’IPA arm64 non signé 0.2.0 a été récupéré et son contenu vérifié.
Exécution : https://github.com/astauhq-dot/LainCord/actions/runs/43390724536
Les essais de connexion et d’appel sur un iPhone réel restent à faire.

La connexion par token dépend du client web Discord et peut ne plus être
acceptée. La connexion classique reste accessible séparément. Le vocal utilise
Discord web ; **aucun appel n’a été validé sur iPhone**. Changer l’identité du
navigateur ne garantit pas la compatibilité WebRTC ni le chiffrement vocal. Si
Discord bloque les appels sous WebKit, cette version ne contient pas de moteur
vocal natif de remplacement.

Les effets, le gain et les sons du studio ne sont pas injectés dans Discord.
Le partage d’écran et les appels en arrière-plan ne sont pas implémentés comme
fonctionnalités natives. L’interface de bureau peut être peu pratique sur iPhone.

## Compiler et obtenir l’IPA

iOS 17 minimum. Sur un Mac avec Xcode :

```sh
bash scripts/build_unsigned_ipa.sh
```

Résultat attendu après compilation réussie : `LainCord-unsigned.ipa`.
Le fichier devra être signé avec un certificat et un profil adaptés.

Sans Mac : déposer **le contenu de ce dossier** à la racine d’un dépôt GitHub,
y compris `.github`. Dans Actions, lancer **Construire LainCord IPA (non signe)**.
Le workflow lance les tests JS, compile pour le simulateur puis pour iPhone,
et fournit l’artefact `LainCord-IPA-non-signe`. Le workflow a été exécuté avec succès. L’IPA est disponible dans les
artefacts de l’exécution indiquée ci-dessus (conservation de sept jours).

## Recette sur appareil

1. Compiler et signer l’IPA, puis installer sur un iPhone iOS 17+.
2. Essayer la connexion classique (dont 2FA si activée), ouvrir un serveur et
   un salon, puis vérifier lecture et envoi d’un message dans un salon de test.
3. Se déconnecter avec le bouton natif. Ouvrir une nouvelle session et vérifier
   que le compte précédent n’est plus connecté.
4. Essayer un token invalide : erreur affichée sans ouverture de session.
   Essayer ensuite son propre token valide, sans le transmettre à un tiers.
5. Rejoindre un vocal de test, autoriser le micro et vérifier avec un second
   participant l’audio dans les deux sens, le mute et la sortie d’appel.
   Refaire le test en refusant la permission du microphone.
6. Fermer la session et vérifier que l’indicateur de micro iOS s’éteint.
7. Vérifier les erreurs hors réseau et le bouton de rechargement.
8. Forcer l’arrêt de l’app puis la relancer : une nouvelle connexion est requise.

Ne considérer la connexion ou le vocal comme fonctionnels qu’après ces essais.
