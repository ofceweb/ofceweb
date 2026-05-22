# build site functions

## Concept 

From a repository, we have a set of functions that help set up a website, render it, deploy it to a branch for publication either on the OFCE servers or on through gh-pages.

We have three functions 
- setup_site()
- render_site()
- site2deploy() 

## setup_site()

setup_site functions should have the follwing workflow : 

### initialization
- scan all qmds in the repo , ignore those that start with "_". get all the titles if there's one in the yaml, use the filename (without qmd otherwise)
- copy from the package files (located for now in inst/setup_site/) :
  - the _quarto.yaml at the root of the repo
  - if in the scanned qmds there is no index.qmd, copy the index.qmd at the root of the repo
  - the content of the folder called wwww needs to be put at the root of the repo in a folder called www
  - the workflow folder which should see the contents of the folder being put in a ".github/workflows/" folder
  - and the extensioms folder


### Editing the quarto.yaml
- replace the stuff in other-links with the titles from the extracted quartos and the approriate href (file_path.html, basically)

- add an argument in the function : `ofce_host` , if TRUE , the site-url in the yml remains "https://www.ofce.fr/". if FALSE then we can remove site-path and site-url

- For the site-path , add an argument called "ofce_server_location" that takes by default the value `"staging"` . then add an argument "website_code" thats by default NULL. this argument should be a string with only letters, numbers and underscores. If this check fails, the website_code reverts to NULL. When NULL, the new variable website_path takes the name of the github repo as obtained by gert::git_remote_list() , the last bit (ofceweb.git without the git) . the site-path variable thus takes whatever is determined for website_path . coherently if ofce_host is false, this doesnt apply
- for now the only site-paths possible for ofce_server_location are "staging" or "wp"

- we add a website_title argument that is NULL by defaul, If not NULLthe title variable in the yaml takes, website_title, otherwise it takes the value of the title in index.qmd if there is one, and otherwise, the name of the repo.

- add a hypothesis argument, takes by default TRUE , and adapts the quarto.yml accordingly

- add an argument in the yaml called ofce_host (that matches ofce_host.)

- add _site in the gitgnore 

- if ofce_host is false, : execute the following commands to setup gh_pages 

---
git checkout --orphan gh-pages
git reset --hard # make sure all changes are committed before running this!
git commit --allow-empty -m "Initialising gh-pages branch"
git push origin gh-pages
---
and go back to whatever github branch we were in previously

## site2deploy() 

- should work like site2branch if ofce_host is TRUE in the yaml, otherwise it does a quarto publish gh-pages


## rescan_pages()

  - a function that scans for new qmds and adds them to the other-links section of the quarto yaml
  when adding pages to the other-links section it should be with the 
  folloing syntax  :   
  
  other-links:
   - text: Annexes
     icon: newspaper
     href: annexes.html  
     
     Where -text is the title of the page if one is in the yaml, otherwise use the basename of the qmd, icon is newspaper bydefault and href is the path to html pages ie if the new_page.qmd is at the root then href is new_page.html , if it's under a subfolder at the root ie subfolder/new_page.qmd, then href is subfolder/new_page.html
