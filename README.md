# cr_eval3

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
**************************************************************
#!/bin/bash
# À lancer depuis la racine de ton projet Flutter.
# Nécessite curl (déjà présent sur Mac/Linux ; sur Windows, utilise Git Bash
# ou WSL) et ImageMagick pour la conversion en PNG (brew install imagemagick
# / choco install imagemagick / apt install imagemagick).
 
mkdir -p assets/images
 
curl -L "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=800&fit=crop" -o assets/images/passage.jpg
curl -L "https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=800&fit=crop" -o assets/images/piste.jpg
curl -L "https://images.unsplash.com/photo-1569629743817-70d8db6c323b?w=800&fit=crop" -o assets/images/ops.jpg
curl -L "https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?w=800&fit=crop" -o assets/images/fret.jpg
curl -L "https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&fit=crop" -o assets/images/garage.jpg
 
# Conversion JPEG -> PNG (comme demandé). Note : le PNG sera nettement plus
# lourd que le JPEG d'origine pour une photo (compression sans perte), ce qui
# alourdit l'app. Si la taille de l'app t'importe, garder le .jpg est
# fonctionnellement identique pour Flutter (voir remarque plus bas).
for f in passage piste ops fret garage; do
  convert "assets/images/$f.jpg" "assets/images/$f.png"
  rm "assets/images/$f.jpg"
done

# que siginifie : curl -L "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=800&fit=crop" -o assets/images/passage.jpg

Cette commande télécharge l'image de l'avion affichée à l'écran depuis le site Unsplash. Elle l'enregistre ensuite localement sur votre ordinateur sous le nom passage.jpg dans le dossier assets/images/.Voici le détail de chaque élément de la commande :

curl : Un outil en ligne de commande utilisé pour transférer des données depuis ou vers un serveur internet.
-L : Cette option force curl à suivre les redirections si le lien de l'image a changé d'adresse."https://images.unsplash..." : 
L'adresse URL exacte de l'image que vous souhaitez récupérer.
-o assets/images/passage.jpg : Indique l'emplacement et le nom du fichier où enregistrer l'image téléchargée.

# where in my flutter app can i rename my name : cr_eval3

To rename the window title cr_eval3 that appears at the top left of your Windows Desktop application, you need to change it inside the native Windows configuration file of your Flutter project.Here is exactly where to find and edit it:The File LocationNavigate to this path in your project directory:📁 windows/runner/main.cppThe Line to EditOpen main.cpp and look for the line where the window is created (usually around line 15-25). You will see a line of code containing cr_eval3.Change that text to your desired title:cpp// Change this line:
if (!window.Create(L"cr_eval3", origin, size)) {

// To your new application name:
if (!window.Create(L"Mon Super Tableau de Bord", origin, size)) {
Utilisez le code avec précaution.Apply the ChangesSave the main.cpp file.Stop your currently running Flutter application.Run flutter run -d windows again to rebuild the application with the new title.