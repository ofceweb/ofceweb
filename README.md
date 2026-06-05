# pkgdown <img src="pkgdown/favicon/favicon-96x96.png" align="right" />

Tout ce qui sert à générer les pages HTML du site web de l'OFCE se trouve ici.

## Installation

Pour installer `{ofceweb}`, utiliser `{pak}` ou `renv::install()`

```r
pak::pak("ofceweb/ofceweb")
# ou 
renv::install("ofceweb/ofceweb")
```
Le package couvre les usages de plusieurs types d'utilisateurs.

## Publier un document de travail en phase _staging_ ou _publication_

Le principe est d'avoir le document de travail dans un repo github, sur son compte personnel ou dans l'organisation OFCE.

Le format du repo est assez libre, un _template_ est proposé, avec quelques éléments obligatoires pour la publication. Le _template_ est implémenté par `setup_wp()`, fonction non destructive qui préserve ce qui est déjà mis en place (yaml, fichiers). `check_wp()` diagnostique l'installation et pointe vers les problèmes non bloquants ou bloquants. 

Tant que le document de travail est en phase _staging_, il est servi par github.com (`gh-pages`). Il est possible de le crypter afin d'en limiter l'accès à un public choisi. La mise en place du cryptage est faite par `encrypt_site()` et le cryptage est enlevé par `remove_encrypt()`. Pour le cryptage, il faut définir un mot de passe **qui ne doit pas être en clair dans le repo**. Pensez à utiliser `usethis::edit_r_environ()` pour définir une variable contenant le mot de passe ou assurez vous que le mot de passe est dans un fichier dans `.gitignore`.

La publication suppose la validation. il faut alors enlever le cryptage, définir un numéro de document de travail et le publier sur le site de l'OFCE. Cela suppose que les identifiants d'accès au site ftp de l'OFCE sont remplis. C'est automatique sur l'organisation OFCE sur github.com. Sinon, il faut demander à un administrateur de renseigner les secrets github sur le repo qui contient le document de travail.

Le document de travail peut être versionné, les différentes versions peuvent être conservées, une url stable est toujours disponible (www.ofce.fr/wp/{YYYY}/{NNN}) pour le document de travail de l'OFCE n°YYYY-NNN. L'url stable pointe vers la dernière version poussée sur le site.

Une fois le document de travail validé, les auteurs peuvent modifier le document de travail librement. En cas d'abus, cet accès peut être retiré.

## Publier un mini-site en phase _staging_ ou _publication_

Un mini-site ressemble beaucoup à un document de travail, à ceci près que le format est plus libre et que le mini-site n'est pas nécessairement publié. A priori, les mini-sites publiés doivent être référencés dans le site général. Merci de contacter les administrateurs dans ce cas.

Le mini-site est mis en place par `setup_site()` (attention, peut être cette fonction est destructive, pensez à commiter avant de l'employer). Il est possiblement crypté (`ofceweb::encrypt_site()`). Le cryptage est enlevé par `remove_encrypt()`. Pour le cryptage, il faut définir un mot de passe **qui ne doit pas être en clair dans le repo**. Pensez à utiliser `usethis::edit_r_environ()` pour définir une variable contenant le mot de passe ou assurez vous que le mot de passe est dans un fichier dans `.gitignore`.

Le mini-site peut être publié sur `gh-pages` comme sur le site de l'OFCE. Notez que le site ne sera référencé s'il n'est pas publié.

La mise à jour du mini-site se fait en le republiant.

## Publier la prévision en phase _staging_ ou _publication_

La prévision est un mini-site particulier. Une version _staging_ (commentaires ouverts, cryptée, non référencée) co existe avec une verison _publish_ (commentaires fermés, url définie (www.ofce.fr/prev/prevYYMM), non cryptée, référencée, suivi statitistique).

Les principales fonctions sont `render_prev()` et `publish_prev()`. Les fonctions helpers seront ajoutées progressivement.

## Administrer les principales pages du site web de l'OFCE

### Le blog

[webblog](https://github.com/ofceweb/webblog) est le repo du blog de l'OFCE. Pour le modifier vous devez avoir les droits.

Pour générer le blog : aller dans le repo [webblog](https://github.com/ofceweb/webblog), lancer `render_blog()` ; avec l'option `site2branch=TRUE`, le rendu est uploadé sur github dans la branche `site-deploy` et envoyé sur le site de l'OFCE ; `site2branch()` fait la même opération. La fonction est documentée pour les options avancées.

Pas de cryptage disponible.

Une github action génère le blog une fois par jour en mode `force_freeze=FALSE` ce qui met à jour les posts périodiques (`freeze: false` dans le yaml).

Le blog relecture sera prochainement inclu dans la procédure.

### La _home page_

[webhome](https://github.com/ofceweb/webhome) est le repo de la home page ; 

Pour générer la *home page*, aller dans le repo [webhome](https://github.com/ofceweb/webhome), lancer `render_home()` ; avec l'option `site2branch=TRUE`, le rendu est uploadé sur github dans la branche `site-deploy` et envoyé sur le site de l'OFCE ; `site2branch()` fait la même opération. La fonction est documentée pour les options avancées.

### les statistiques de fréquention et de production

[webstat](https://github.com/ofceweb/webstat) est le repo du dashboard des statistiques de fréquentation (crytpé) ;

Pour générer le [dashboard de fréquentation webstat](https://www.ofce.fr/webstat) : aller dans le repo [webstat](https://github.com/ofceweb/webstat), et pusher sur main, le site est généré à partir de cet évènement ; 2 fois par jour webstat est actualisé.


### Prochainement le nowcast

Le [nowcast](https://github.com/ofceweb/nowcast) a bientôt sa page. Il est en cours de développement
