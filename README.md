# DE10 LITE : Projet Carillon

**Auteur :** Daniel THIRION | *DUT GEII Salon S1 Gr1A*

**Nom :** Generateur1A.vhd

**Carte :** DE10-LITE (MAX10 Family - 50K LE)

## Description :

Ce programme permet d'encoder un carillon dans la mémoire de la carte, puis de le rejouer

Il ressort le carillon sous forme d'une dent-de-scie, d'un sinus (sur 4 bits) ou d'un signal modulé en largeur (PWM), qui peut être lu grace à un filtre passe bas.

### Controles :

- Le switch le plus à gauche permet de passer en mode "setup" où l'on peut régler le carillon.
En mode setup, l'afficheur 7 segment s'allume.

- Le second switch permet d'enregistrer la note et de passer à la suivante au front montant.
On peut suivre la note actuellement modifiée grace aux LEDs qui affichent en binaire le compte.

- Les 8 derniers switchs sont un "piano", de DO à DO. La note la plus à gauche prends le dessus si plusieurs sont enfoncées.

- Le fait d'en enfoncer aucune permet de faire une note vierge, une pause dans le carillon.

- Le fait de toutes les enfoncer permet de marquer la fin du carillon. Le programme reviendra a la première note si il rencontre ce signal.

- Le carillon est composé de maximum 32 notes. Il se joueras automatiquement lorsque l'on est hors du "setup"

- La sortie PWM est sur GPIO(0), le sinus sur la sortie bleue du VGA, et la dent de scie sur la sortie rouge.