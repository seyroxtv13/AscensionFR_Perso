# Faux positif antivirus (Compagnon .exe)

## Pour toi (maintenant)

1. Ouvre la release : https://github.com/seyroxtv13/AscensionFR_Perso/releases/tag/v1.0.0  
2. Si le `.exe` est refusé → prends **`AscensionFR_Perso.zip`** pour l’addon.  
3. Pour le Compagnon malgré Defender :
   - Chrome/Edge : **Conservez** / **Autres infos** → **Exécuter quand même**
   - Fichier téléchargé : clic droit → Propriétés → **Débloquer**
   - Ou lance sans build : `python compagnon/compagnon.py`

## Pour Microsoft (whitelist)

https://www.microsoft.com/en-us/wdsi/filesubmission  
Type : **false positive / incorrectly detected**.

## Technique

PyInstaller one-file non signé = heuristique ML fréquente.  
UPX déjà désactivé. Métadonnées PE (`version_info.txt`) ajoutées pour les prochaines builds.  
Seul vrai remède durable : certificat de signature de code (payant).
