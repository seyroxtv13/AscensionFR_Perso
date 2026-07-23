# -*- coding: utf-8 -*-
"""
AscensionFR Perso — Compagnon
Composition unique : marque → statut → action → chemin.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import sys
import tempfile
import threading
import webbrowser
import zipfile
import tkinter as tk
from tkinter import filedialog, messagebox
import urllib.request

from PIL import Image, ImageTk

DEPOT = os.environ.get("AFRP_DEPOT", "seyroxtv13/AscensionFR_Perso")
API_RELEASE = f"https://api.github.com/repos/{DEPOT}/releases/latest"
PAGE_RELEASES = f"https://github.com/{DEPOT}/releases"
ZIP_ATTENDU = "AscensionFR_Perso.zip"
ADDON_NAME = "AscensionFR_Perso"
ANCIEN = "AscensionFR"
VERSION_COMPAGNON = "1.0.0"
UA = {"User-Agent": "AscensionFR-Perso/1.0"}
NOM = "AscensionFR Perso"

CONFIG_DIR = os.path.join(os.environ.get("APPDATA", "."), "AscensionFR_Perso")
CONFIG = os.path.join(CONFIG_DIR, "compagnon.json")
W, H = 520, 560

CUIVRE = "#d27d37"
TEXTE = "#f0f3f8"
MUTE = "#8b96a8"
OK = "#4bb978"
WARN = "#e0a020"
ERR = "#e05555"
GLACE = "#82b8d8"


def ressource(*parts):
    if getattr(sys, "frozen", False):
        base = getattr(sys, "_MEIPASS", os.path.dirname(sys.executable))
    else:
        base = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base, *parts)


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
    return bool(chemin) and (
        os.path.isdir(os.path.join(chemin, "Interface", "AddOns"))
        or os.path.isdir(os.path.join(chemin, "Data"))
    )


def version_installee(jeu, nom=ADDON_NAME):
    toc = os.path.join(jeu, "Interface", "AddOns", nom, f"{nom}.toc")
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


def en_tuple(v):
    return tuple(int(x) for x in re.findall(r"\d+", v or "0"))


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
    with urllib.request.urlopen(req, timeout=600) as r:
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
    addons = os.path.join(jeu, "Interface", "AddOns")
    os.makedirs(addons, exist_ok=True)
    cible = os.path.join(addons, ADDON_NAME)
    with zipfile.ZipFile(chemin_zip) as z:
        noms = [n.replace("\\", "/") for n in z.namelist()]
        tmp = tempfile.mkdtemp(prefix="afrp_")
        try:
            z.extractall(tmp)
            if any(n.startswith("Interface/AddOns/") for n in noms):
                src = os.path.join(tmp, "Interface", "AddOns", ADDON_NAME)
            elif any(n.startswith(f"{ADDON_NAME}/") for n in noms):
                src = os.path.join(tmp, ADDON_NAME)
            else:
                src = tmp
            if not os.path.isfile(os.path.join(src, f"{ADDON_NAME}.toc")):
                for root, _dirs, files in os.walk(tmp):
                    if f"{ADDON_NAME}.toc" in files:
                        src = root
                        break
            if os.path.isdir(cible):
                shutil.rmtree(cible)
            shutil.copytree(src, cible)
            for junk in ("compagnon", "dist", "release", "scripts", ".git", "README.md"):
                p = os.path.join(cible, junk)
                if os.path.isdir(p):
                    shutil.rmtree(p, ignore_errors=True)
                elif os.path.isfile(p):
                    try:
                        os.remove(p)
                    except OSError:
                        pass
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


def raccourcir(chemin, n=46):
    if not chemin:
        return "Choisis le dossier du jeu…"
    if len(chemin) <= n:
        return chemin
    return "…" + chemin[-(n - 1):]


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(f"{NOM}  ·  Compagnon")
        self.geometry(f"{W}x{H}")
        self.resizable(False, False)
        self.configure(bg="#0c0f16")
        self.jeu = detecter_jeu()
        self.derniere = self.url_zip = None
        self._photos = {}
        self._mode = "install"
        self._assurer_assets()
        self._icone()
        self._ui()
        self.after(120, self.verifier)

    def _assurer_assets(self):
        if not os.path.isfile(ressource("assets", "ui", "fond.png")):
            import fabriquer_decor
            fabriquer_decor.main()

    def _ph(self, nom):
        if nom in self._photos:
            return self._photos[nom]
        path = ressource("assets", "ui", nom)
        if not os.path.isfile(path):
            return None
        self._photos[nom] = ImageTk.PhotoImage(Image.open(path).convert("RGBA"))
        return self._photos[nom]

    def _icone(self):
        try:
            ico = ressource("assets", "icon.ico")
            if os.path.isfile(ico):
                self.iconbitmap(ico)
        except Exception:
            pass

    def _ui(self):
        cv = tk.Canvas(self, width=W, height=H, highlightthickness=0, bg="#0c0f16")
        cv.pack(fill="both", expand=True)
        self.cv = cv

        fond = self._ph("fond.png")
        if fond:
            cv.create_image(0, 0, anchor="nw", image=fond)

        # Marque
        crest = ressource("assets", "crest.png")
        if os.path.isfile(crest):
            try:
                im = Image.open(crest).convert("RGBA").resize((56, 56))
                self._photos["crest"] = ImageTk.PhotoImage(im)
                cv.create_image(36, 36, anchor="nw", image=self._photos["crest"])
            except Exception:
                pass

        cv.create_text(108, 40, anchor="nw", text="AscensionFR Perso",
                       fill=TEXTE, font=("Segoe UI Semibold", 18))
        cv.create_text(108, 70, anchor="nw", text="Traduction française pour Ascension",
                       fill=MUTE, font=("Segoe UI", 10))

        line = self._ph("line.png")
        if line:
            cv.create_image(32, 118, anchor="nw", image=line)

        # Statut (héros)
        self.t_titre = cv.create_text(36, 150, anchor="nw", text="…",
                                      fill=TEXTE, font=("Segoe UI Semibold", 28))
        self.t_sous = cv.create_text(36, 198, anchor="nw", text="",
                                     fill=MUTE, font=("Segoe UI", 11), width=448)
        self.t_hint = cv.create_text(36, 232, anchor="nw", text="",
                                     fill=CUIVRE, font=("Segoe UI", 9), width=448)

        # Bouton principal (caché si déjà prêt)
        self.img_btn = {
            "install": self._ph("btn_install.png"),
            "update": self._ph("btn_update.png"),
            "reinstall": self._ph("btn_reinstall.png"),
        }
        self.id_btn = cv.create_image(110, 280, anchor="nw",
                                      image=self.img_btn["install"], tags=("go_maj",))
        cv.tag_bind("go_maj", "<Button-1>", lambda e: self.lancer_maj())
        cv.tag_bind("go_maj", "<Enter>", lambda e: self.config(cursor="hand2"))
        cv.tag_bind("go_maj", "<Leave>", lambda e: self.config(cursor=""))

        self.prog = tk.Canvas(self, width=448, height=4, bg="#151a24", highlightthickness=0)
        self.id_prog = cv.create_window(36, 344, anchor="nw", window=self.prog, state="hidden")
        self._bar = self.prog.create_rectangle(0, 0, 0, 4, fill=CUIVRE, width=0)

        # Chemin — une ligne, pas une carte
        if line:
            cv.create_image(32, 380, anchor="nw", image=line)
        cv.create_text(36, 400, anchor="nw", text="Dossier du jeu",
                       fill=MUTE, font=("Segoe UI", 8))
        self.t_path = cv.create_text(36, 422, anchor="nw", text=raccourcir(self.jeu),
                                     fill=TEXTE, font=("Consolas", 9))
        b1 = self._ph("btn_browse.png")
        if b1:
            cv.create_image(388, 412, anchor="nw", image=b1, tags=("go_browse",))
            cv.tag_bind("go_browse", "<Button-1>", lambda e: self.parcourir())
            cv.tag_bind("go_browse", "<Enter>", lambda e: self.config(cursor="hand2"))
            cv.tag_bind("go_browse", "<Leave>", lambda e: self.config(cursor=""))

        # Pied minimal
        cv.create_text(36, 500, anchor="nw",
                       text=f"Compagnon {VERSION_COMPAGNON}",
                       fill=MUTE, font=("Segoe UI", 8))
        bweb = self._ph("btn_web.png")
        if bweb:
            cv.create_image(388, 490, anchor="nw", image=bweb, tags=("go_web",))
            cv.tag_bind("go_web", "<Button-1>", lambda e: webbrowser.open(PAGE_RELEASES))
            cv.tag_bind("go_web", "<Enter>", lambda e: self.config(cursor="hand2"))
            cv.tag_bind("go_web", "<Leave>", lambda e: self.config(cursor=""))

    def set_prog(self, ratio, show=True):
        self.cv.itemconfigure(self.id_prog, state="normal" if show else "hidden")
        if not show:
            return
        self.prog.update_idletasks()
        w = max(self.prog.winfo_width(), 1)
        self.prog.coords(self._bar, 0, 0, int(w * max(0, min(1, ratio))), 4)

    def afficher(self, titre, sous, hint, couleur, mode):
        self.cv.itemconfigure(self.t_titre, text=titre, fill=couleur)
        self.cv.itemconfigure(self.t_sous, text=sous)
        self.cv.itemconfigure(self.t_hint, text=hint or "")
        self._mode = mode
        # Toujours un bouton visible
        if mode == "update":
            key = "update"
        elif mode == "ok":
            key = "reinstall"
        elif mode == "install":
            key = "install"
        else:
            key = "install"
        img = self.img_btn.get(key) or self.img_btn["install"]
        self.cv.itemconfigure(self.id_btn, image=img, state="normal")

    def parcourir(self):
        chemin = filedialog.askdirectory(title="Dossier du jeu Ascension")
        if chemin:
            self.jeu = chemin
            self.cv.itemconfigure(self.t_path, text=raccourcir(chemin))
            cfg = charger_config()
            cfg["jeu"] = chemin
            sauver_config(cfg)
            self.verifier()

    def verifier(self):
        self.afficher("Un instant…", "Vérification de la dernière version…", "", MUTE, "busy")
        self.set_prog(0, False)

        def travail():
            try:
                d, u = derniere_release()
                err = None
            except Exception as e:
                d, u, err = None, None, str(e)
            self.after(0, lambda: self._apres(d, u, err))

        threading.Thread(target=travail, daemon=True).start()

    def _apres(self, derniere, url, err):
        self.derniere, self.url_zip = derniere, url
        if not jeu_valide(self.jeu):
            self.afficher(
                "Où est le jeu ?",
                "Indique le dossier Ascension (celui avec Interface\\AddOns).",
                "", WARN, "install",
            )
            return

        inst = version_installee(self.jeu)
        anc = version_installee(self.jeu, ANCIEN)
        # Un seul message sur l’ancien addon
        hint = (
            f"IMPORTANT : désactive AscensionFR {anc} (Esc → AddOns) pour n’utiliser que Perso."
            if anc else
            "AscensionFR est désactivé / absent — Perso tourne seul."
        )

        if err:
            self.afficher("Hors ligne", err[:100], hint, ERR, "busy")
            return
        if not url:
            self.afficher("Release incomplète", f"Manque {ZIP_ATTENDU} sur GitHub.", hint, ERR, "busy")
            return
        if not inst:
            self.afficher(
                "À installer",
                f"La version {derniere} est prête.",
                hint, WARN, "install",
            )
        elif derniere and en_tuple(derniere) > en_tuple(inst):
            self.afficher(
                "Mise à jour",
                f"Tu as {inst} → nouvelle version {derniere}.",
                hint, WARN, "update",
            )
        else:
            self.afficher(
                "Prêt à jouer",
                f"Perso {inst} est installé.",
                hint, OK, "ok",
            )

    def lancer_maj(self):
        if self._mode == "busy":
            return
        # install / update / reinstall → toujours télécharger
        if not self.url_zip:
            messagebox.showerror(NOM, "Pas d’URL de téléchargement.")
            return
        label = "Réinstallation…" if self._mode == "ok" else "Installation…"
        self.afficher(label, f"Téléchargement de la {self.derniere}…", "", MUTE, "busy")
        self.set_prog(0.05, True)
        url, jeu = self.url_zip, self.jeu

        def travail():
            try:
                def prog(fait, total):
                    r = (fait / total) if total else 0.1
                    self.after(0, lambda: self.set_prog(r, True))

                chemin = telecharger(url, prog)
                self.after(0, lambda: self.set_prog(0.9, True))
                installer_zip(chemin, jeu)
                cfg = charger_config()
                cfg["jeu"] = jeu
                sauver_config(cfg)
                self.after(0, self._ok)
            except Exception as e:
                self.after(0, lambda: self._fail(str(e)))

        threading.Thread(target=travail, daemon=True).start()

    def _ok(self):
        self.set_prog(1, True)
        self.afficher(
            "Installé",
            "Relance le jeu (ou /reload), puis tape /afrp.",
            "Tu peux désactiver AscensionFR dans la liste des addons.",
            OK, "ok",
        )
        self.after(800, self.verifier)

    def _fail(self, msg):
        self.set_prog(0, False)
        self.afficher("Échec", msg[:110], "", ERR, "install")


if __name__ == "__main__":
    App().mainloop()
