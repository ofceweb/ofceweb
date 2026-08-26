# Nouveau processus de publication des documents de travail OFCE

*Note à l'équipe — août 2026*

---

## Pourquoi ce changement ?

L'ancien système permettait à n'importe quel dépôt GitHub de revendiquer
n'importe quel numéro de WP lors de son premier déploiement, sans autorisation
préalable. Il était également possible de contourner la protection existante en
choisissant un numéro de version personnalisé. Ces deux failles pouvaient
conduire à l'écrasement accidentel (ou malveillant) d'un document de travail
déjà publié sur le site de l'OFCE.

La solution retenue est un **registre central** (`ofceweb/wp-registry`) dans
lequel un administrateur valide explicitement l'association entre un numéro
de WP et le dépôt GitHub qui a le droit de le publier. Aucun dépôt ne peut
publier un WP numéroté sans figurer dans ce registre.

---

## Les trois états d'un document de travail

Un WP passe désormais par trois états successifs.

### 1. Brouillon initial

Le dépôt est créé et configuré avec `setup_wp()`, mais aucune demande de
numéro n'a encore été soumise. Le rendu produit une prévisualisation sur
**GitHub Pages** (`https://ofce.github.io/{nom-du-depot}/`). C'est un lien
temporaire, à usage interne, qui s'écrase à chaque nouveau rendu.

### 2. Staging (en attente de validation)

L'auteur·e a demandé un numéro via `wp_registry_request()`. Une pull request
est ouverte dans le registre central, en attente d'approbation par un
administrateur web. En attendant, chaque rendu dépose le document sur le
**serveur FTP de l'OFCE dans un espace de staging** à l'adresse :

```
https://www.ofce.fr/stage/wp/{nom-du-depot}/v1/
```

Contrairement à GitHub Pages, cet espace est **versionné** : chaque version
envoyée à des relecteurs (v1, v2, v3…) reste accessible à son URL propre.
Les relecteurs peuvent donc conserver leurs liens même si une nouvelle version
est déposée. Les versions de staging sont conservées indéfiniment jusqu'à
décision explicite de l'administrateur.

### 3. Publié

La pull request dans le registre a été fusionnée par un administrateur. Lors
du rendu suivant, le document est automatiquement déployé sur le chemin
numéroté définitif :

```
https://www.ofce.fr/wp/{annee}/{numero}/{version}/
```

Le numéro et l'année sont désormais **attribués par le registre**, non par
l'auteur·e. La redirection vers l'URL stable (sans segment de version) est
gérée automatiquement.

---

## Ce que fait l'auteur·e, étape par étape

```
1. setup_wp()             Initialise le dépôt (une fois)
2. [rédaction du WP]
3. render_wp()            Rendu + prévisualisation locale
4. deploy_wp()            → GitHub Pages (brouillon)

        — quand le WP est prêt pour la numérotation —

5. wp_registry_request()  Demande un numéro (ouvre une PR dans le registre)
6. render_wp()            Rendu + dépôt en staging FTP
7. deploy_wp()            → FTP staging (url versionnée)

        — après approbation admin et fusion de la PR —

8. render_wp()            Détecte automatiquement l'enregistrement
9. deploy_wp()            → FTP production (url numérotée définitive)
```

Les étapes 6–7 peuvent être répétées autant de fois que nécessaire pendant la
relecture (chaque `wp_version_up()` incrémente la version et crée une nouvelle
URL de staging).

---

## Décisions clés et leurs raisons

### Le registre est dans `ofceweb/wp-registry`, pas dans `ofce`

Le registre est un dépôt **public**, ce qui permet aux workflows GitHub Actions
de le lire sans avoir besoin d'un secret ou d'un token. Il est hébergé dans
l'organisation `ofceweb` (distincte de `ofce`) pour séparer les
responsabilités : `ofce` héberge les dépôts des WP, `ofceweb` héberge
l'infrastructure web.

### L'appartenance à l'organisation `ofce` est obligatoire pour publier

Les secrets FTP de production (`WP_USER`, `WP_PASSWORD`) sont stockés au
niveau de l'organisation `ofce`. Un dépôt hors de cette organisation n'y a
simplement pas accès — la protection est donc structurelle, pas seulement
procédurale. La demande de numéro (`wp_registry_request()`) est également
bloquée si le dépôt n'est pas dans `ofce`.

Le **rendu local** fonctionne sans restriction d'organisation : un auteur peut
rédiger et prévisualiser son WP depuis n'importe quel dépôt, puis transférer
la propriété vers `ofce` avant de demander un numéro.

### Le staging utilise des credentials FTP distincts avec chroot

Les secrets de staging (`STAGING_USERNAME`, `STAGING_PASSWORD`) sont
différents des secrets de production. Le compte FTP de staging est configuré
côté serveur avec un **chroot sur le dossier `stage/`** : même si un dépôt
mal configuré tentait d'écrire hors de son espace de staging, le serveur
l'en empêcherait. La sécurité est garantie côté serveur, pas seulement par
les workflows.

### La vérification du registre a lieu au moment du rendu, pas du déploiement

`render_wp()` consulte le registre **avant** de lancer Quarto. Cela permet :
- d'injecter un bandeau « Version provisoire — non publiée » dans le HTML, le
  PDF et le Typst produits (géré par les extensions `ofce-quarto-extensions`) ;
- d'écrire le champ `stage` dans `manifest.json`, que `deploy_wp()` lit
  ensuite pour choisir la bonne destination (staging ou production).

Le workflow `ftp_deploy.yml` effectue sa propre vérification indépendante au
moment du déploiement, comme deuxième ligne de défense.

### La citation n'est pas requise pour le rendu

Le champ `citation` dans `_quarto.yml` est calculé automatiquement par
`setup_wp()` à partir de `annee` et `wp`. Il n'est pas pertinent en mode
staging (pas encore de numéro) et n'est jamais un bloquant pour le rendu :
son absence génère un avertissement invitant à relancer `setup_wp()`.

---

## Pour les administrateurs web

La seule action requise de la part de l'administration est de **fusionner (ou
rejeter) les pull requests** ouvertes dans `ofceweb/wp-registry`. Chaque PR
contient le nom du dépôt demandeur, l'année, le numéro proposé et l'adresse
de contact de l'auteur·e. Un CI vérifie que le numéro demandé n'est pas déjà
pris avant d'autoriser la fusion.

L'administrateur actuel du registre est **xtimbeau**. Une équipe
`wp-admins` dans l'organisation `ofceweb` est prévue pour élargir ce rôle si
nécessaire.

---

*Ce processus est implémenté dans le package R `ofceweb` v0.9.0.*
