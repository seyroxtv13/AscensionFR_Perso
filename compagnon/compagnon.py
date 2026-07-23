# -*- coding: utf-8 -*-
"""
AscensionFR Perso — Compagnon (MVP)
Installe / met à jour UNIQUEMENT l'addon AscensionFR_Perso depuis GitHub Releases.
Ne touche pas à AscensionFR officiel.
"""
from __future__ import annotations

import json
import os
import re
import threading
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
import urllib.request
import zipfile
import tempfile
import shutil

# À adapter si ton dépôt GitHub a un autre nom / propriétaire.
DEPOT = os.environ.get("AFRP_DEPOT", "Seyrox/AscensionFR_Perso")
API_RELEASE = f"https://api.github.com/repos/{DEPOT}/releases/latest"
PAGE_RELEASES = f"https://github.com/{DEPOT}/releases"
ZIP_ATTENDU = "AscensionFR_Perso.zip"
ADDON_NAME = "AscensionFR_Perso"
VERSION_COMPAGNON = "0.1.0"
UA = {"User-Agent": "AscensionFR-Perso-Compagnon"}

CONFIG_DIR = os.path.join(os.environ.get("APPDATA", "."), "AscensionFR_Perso")
CONFIG = os.path.join(CONFIG_DIR, "compagnon.json")

FOND = "#0e1013"
PANNEAU = "#16191d"
TEXTE = "#eceff3"
DISCRET = "#8b929c"
ACCENT = "#e8c25a"
VERT = "#2fb46a"
ORANGE = "#e8a33d"
ROUGE = "#e05252"


def charger_config():
    try:
        with open(CONFIG, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def sauver_config(data):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    with open(CONFIG, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


def jeu_valide(chemin):
    if not chemin:
        return False
    return os.path.isdir(os.path.join(chemin, "Interface", "AddOns")) or os.path.isdir(
        os.path.join(chemin, "Data")
    )


def chemin_addon(jeu):
    return os.path.join(jeu, "Interface", "AddOns", ADDON_NAME)


def version_installee(jeu):
    toc = os.path.join(chemin_addon(jeu), f"{ADDON_NAME}.toc")
    if not os.path.isfile(toc):
        return None
    try:
        with open(toc, "r", encoding="utf-8", errors="ignore") as f:
            for ligne in f:
                m = re.match(r"##\s*Version:\s*([\d.]+)", ligne)
                if m:
                    return m.group(1)
    except OSError:
        pass
    return None


def en_tuple(version):
    return tuple(int(x) for x in re.findall(r"\d+", version or "0"))


def derniere_release():
    req = urllib.request.Request(API_RELEASE, headers=UA)
    with urllib.request.urlopen(req, timeout=20) as r:
        infos = json.loads(r.read().decode("utf-8"))
    version = (infos.get("tag_name") or "").lstrip("vV")
    url_zip = None
    for asset in infos.get("assets") or []:
        if asset.get("name") == ZIP_ATTENDU:
            url_zip = asset.get("browser_download_url")
            break
    return version, url_zip


def telecharger(url, progres=None):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r:
        total = int(r.headers.get("Content-Length") or 0)
        fd, chemin = tempfile.mkstemp(suffix=".zip")
        os.close(fd)
        fait = 0
        with open(chemin, "wb") as out:
            while True:
                bloc = r.read(65536)
                if not bloc:
                    break
                out.write(bloc)
                fait += len(bloc)
                if progres:
                    progres(fait, total)
        return chemin


def installer_zip(chemin_zip, jeu):
    """Extrait le zip. Accepte soit Interface/AddOns/..., soit AscensionFR_Perso/..."""
    addons = os.path.join(jeu, "Interface", "AddOns")
    os.makedirs(addons, exist_ok=True)
    cible = os.path.join(addons, ADDON_NAME)
    with zipfile.ZipFile(chemin_zip) as z:
        noms = z.namelist()
        if any(n.replace("\\", "/").startswith("Interface/AddOns/") for n in noms):
            z.extractall(jeu)
        else:
            # zip plat : dossier AscensionFR_Perso/ à la racine
            tmp = tempfile.mkdtemp(prefix="afrp_")
            try:
                z.extractall(tmp)
                src = os.path.join(tmp, ADDON_NAME)
                if not os.path.isdir(src):
                    # fichiers à la racine du zip
                    src = tmp
                if os.path.isdir(cible):
                    shutil.rmtree(cible)
                if os.path.basename(src) == ADDON_NAME:
                    shutil.copytree(src, cible)
                else:
                    os.makedirs(cible, exist_ok=True)
                    for nom in os.listdir(src):
                        s = os.path.join(src, nom)
                        d = os.path.join(cible, nom)
                        if os.path.isdir(s):
                            if os.path.isdir(d):
                                shutil.rmtree(d)
                            shutil.copytree(s, d)
                        else:
                            shutil.copy2(s, d)
            finally:
                shutil.rmtree(tmp, ignore_errors=True)
    try:
        os.remove(chemin_zip)
    except OSError:
        pass


def detecter_jeu():
    candidats = [
        r"E:\Play Ascension\resources\ascension-live",
        r"C:\Program Files (x86)\Ascension Launcher\resources\ascension-live",
        r"C:\Program Files\Ascension Launcher\resources\ascension-live",
    ]
    cfg = charger_config()
    if cfg.get("jeu"):
        candidats.insert(0, cfg["jeu"])
    for c in candidats:
        if jeu_valide(c):
            return c
    return ""


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(f"AscensionFR Perso — Compagnon {VERSION_COMPAGNON}")
        self.geometry("520x360")
        self.configure(bg=FOND)
        self.resizable(False, False)

        self.jeu = detecter_jeu()
        self.derniere = None
        self.url_zip = None

        style = ttk.Style(self)
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass

        cadre = tk.Frame(self, bg=PANNEAU, padx=16, pady=16)
        cadre.pack(fill="both", expand=True, padx=16, pady=16)

        tk.Label(
            cadre,
            text="ASCENSIONFR PERSO",
            bg=PANNEAU,
            fg=ACCENT,
            font=("Segoe UI", 14, "bold"),
        ).pack(anchor="w")
        tk.Label(
            cadre,
            text="Overlay FR — survit aux mises à jour d'AscensionFR",
            bg=PANNEAU,
            fg=DISCRET,
            font=("Segoe UI", 9),
        ).pack(anchor="w", pady=(0, 12))

        tk.Label(cadre, text="Dossier du jeu", bg=PANNEAU, fg=DISCRET).pack(anchor="w")
        ligne = tk.Frame(cadre, bg=PANNEAU)
        ligne.pack(fill="x", pady=(2, 8))
        self.var_jeu = tk.StringVar(value=self.jeu)
        tk.Entry(ligne, textvariable=self.var_jeu, bg="#1c2128", fg=TEXTE, insertbackground=TEXTE).pack(
            side="left", fill="x", expand=True
        )
        tk.Button(ligne, text="Parcourir…", command=self.parcourir, bg=PANNEAU, fg=TEXTE).pack(
            side="left", padx=(8, 0)
        )

        self.lbl_version = tk.Label(
            cadre, text="Vérification…", bg=PANNEAU, fg=TEXTE, font=("Segoe UI", 10)
        )
        self.lbl_version.pack(anchor="w", pady=(8, 4))

        self.lbl_etat = tk.Label(cadre, text="", bg=PANNEAU, fg=DISCRET)
        self.lbl_etat.pack(anchor="w", pady=(0, 12))

        self.btn_maj = tk.Button(
            cadre,
            text="Installer / Mettre à jour",
            command=self.lancer_maj,
            bg=ACCENT,
            fg="#15130c",
            font=("Segoe UI", 10, "bold"),
            relief="flat",
            padx=12,
            pady=8,
        )
        self.btn_maj.pack(anchor="w")

        tk.Label(
            cadre,
            text=f"Dépôt : github.com/{DEPOT}",
            bg=PANNEAU,
            fg=DISCRET,
            font=("Segoe UI", 8),
        ).pack(anchor="w", pady=(16, 0))

        self.after(200, self.verifier)

    def etat(self, texte, couleur=DISCRET):
        self.lbl_etat.configure(text=texte, fg=couleur)

    def parcourir(self):
        chemin = filedialog.askdirectory(title="Dossier Ascension (ascension-live)")
        if chemin:
            self.var_jeu.set(chemin)
            self.jeu = chemin
            cfg = charger_config()
            cfg["jeu"] = chemin
            sauver_config(cfg)
            self.verifier()

    def verifier(self):
        self.jeu = self.var_jeu.get().strip()
        self.btn_maj.configure(state="disabled")
        self.lbl_version.configure(text="Contact GitHub…")

        def travail():
            try:
                derniere, url = derniere_release()
                err = None
            except Exception as e:
                derniere, url, err = None, None, str(e)
            self.after(0, lambda: self._apres_verif(derniere, url, err))

        threading.Thread(target=travail, daemon=True).start()

    def _apres_verif(self, derniere, url, err):
        self.derniere, self.url_zip = derniere, url
        if not jeu_valide(self.jeu):
            self.lbl_version.configure(text="Choisis le dossier du jeu (ascension-live).")
            self.etat("Dossier invalide — Interface\\AddOns introuvable.", ORANGE)
            self.btn_maj.configure(state="disabled")
            return
        inst = version_installee(self.jeu)
        if err:
            self.lbl_version.configure(
                text=f"Installée : {inst or '—'} — GitHub injoignable."
            )
            self.etat(err, ROUGE)
            # Permettre quand même une install locale si zip manuel plus tard
            self.btn_maj.configure(state="disabled")
            return
        if not inst:
            self.lbl_version.configure(
                text=f"Non installé — dernière release : {derniere or '?'}"
            )
            self.btn_maj.configure(state="normal", text="Installer AscensionFR_Perso")
            self.etat("Prêt à installer.", VERT)
        elif derniere and en_tuple(derniere) > en_tuple(inst):
            self.lbl_version.configure(text=f"Installée : {inst} → disponible : {derniere}")
            self.btn_maj.configure(state="normal", text="Mettre à jour")
            self.etat("Une nouvelle version est disponible.", ORANGE)
        else:
            self.lbl_version.configure(text=f"Installée : {inst} — à jour")
            self.btn_maj.configure(state="normal", text="Réinstaller")
            self.etat("Tout est à jour.", VERT)
        if not url:
            self.btn_maj.configure(state="disabled")
            self.etat(
                f"Pas d'asset {ZIP_ATTENDU} sur la dernière release. "
                f"Voir {PAGE_RELEASES}",
                ORANGE,
            )

    def lancer_maj(self):
        if not self.url_zip:
            messagebox.showerror("Erreur", "Aucune URL de zip.")
            return
        self.btn_maj.configure(state="disabled", text="Téléchargement…")
        self.etat("Téléchargement…", DISCRET)
        url = self.url_zip
        jeu = self.var_jeu.get().strip()

        def travail():
            try:

                def prog(fait, total):
                    if total:
                        txt = f"Téléchargement… {fait * 100 // total} %"
                    else:
                        txt = f"Téléchargement… {fait / 1048576:.1f} Mo"
                    self.after(0, lambda: self.etat(txt, DISCRET))

                chemin = telecharger(url, prog)
                self.after(0, lambda: self.etat("Installation…", DISCRET))
                installer_zip(chemin, jeu)
                cfg = charger_config()
                cfg["jeu"] = jeu
                sauver_config(cfg)
                self.after(0, lambda: self._ok())
            except Exception as e:
                self.after(0, lambda: self._fail(str(e)))

        threading.Thread(target=travail, daemon=True).start()

    def _ok(self):
        self.etat("Installé. En jeu : coche AscensionFR_Perso + /reload.", VERT)
        self.verifier()

    def _fail(self, msg):
        self.etat(msg, ROUGE)
        self.btn_maj.configure(state="normal", text="Réessayer")


if __name__ == "__main__":
    App().mainloop()
