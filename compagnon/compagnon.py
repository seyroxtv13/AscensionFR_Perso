# -*- coding: utf-8 -*-
"""
AscensionFR Perso — Compagnon
Installe / met à jour UNIQUEMENT AscensionFR_Perso.
Ne touche jamais au dossier AscensionFR officiel.
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

DEPOT = os.environ.get("AFRP_DEPOT", "seyroxtv13/AscensionFR_Perso")
API_RELEASE = f"https://api.github.com/repos/{DEPOT}/releases/latest"
PAGE_RELEASES = f"https://github.com/{DEPOT}/releases"
PAGE_REPO = f"https://github.com/{DEPOT}"
ZIP_ATTENDU = "AscensionFR_Perso.zip"
ADDON_NAME = "AscensionFR_Perso"
OFFICIEL = "AscensionFR"
VERSION_COMPAGNON = "0.2.2"
UA = {"User-Agent": "AscensionFR-Perso-Compagnon/0.2"}

CONFIG_DIR = os.path.join(os.environ.get("APPDATA", "."), "AscensionFR_Perso")
CONFIG = os.path.join(CONFIG_DIR, "compagnon.json")


def ressource(*parts):
    """Fichier embarqué (PyInstaller) ou voisin du script."""
    if getattr(sys, "frozen", False):
        base = getattr(sys, "_MEIPASS", os.path.dirname(sys.executable))
    else:
        base = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base, *parts)

# Palette launcher sombre + or (proche AscensionFR, plus épurée)
FOND = "#0a0c0f"
CARTE = "#12151a"
CARTE2 = "#181c22"
LISERE = "#2a3038"
TEXTE = "#f0f2f5"
MUTE = "#8a929c"
ACCENT = "#f0c14b"
ACCENT2 = "#d4a017"
VERT = "#3dd68c"
ORANGE = "#f5a524"
ROUGE = "#ff6b6b"
BLEU = "#5eb1ff"


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


def chemin_addon(jeu, nom=ADDON_NAME):
    return os.path.join(jeu, "Interface", "AddOns", nom)


def version_installee(jeu, nom=ADDON_NAME):
    toc = os.path.join(chemin_addon(jeu, nom), f"{nom}.toc")
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
    return version, url_zip, (infos.get("body") or "").strip()


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
    """Écrit uniquement Interface/AddOns/AscensionFR_Perso — jamais AscensionFR."""
    addons = os.path.join(jeu, "Interface", "AddOns")
    os.makedirs(addons, exist_ok=True)
    cible = os.path.join(addons, ADDON_NAME)
    with zipfile.ZipFile(chemin_zip) as z:
        noms = [n.replace("\\", "/") for n in z.namelist()]
        if any(n.startswith("Interface/AddOns/") for n in noms):
            # Extraction ciblée : seulement notre addon
            tmp = tempfile.mkdtemp(prefix="afrp_")
            try:
                z.extractall(tmp)
                src = os.path.join(tmp, "Interface", "AddOns", ADDON_NAME)
                if not os.path.isdir(src):
                    raise RuntimeError("Zip invalide : dossier AscensionFR_Perso manquant.")
                if os.path.isdir(cible):
                    shutil.rmtree(cible)
                shutil.copytree(src, cible)
            finally:
                shutil.rmtree(tmp, ignore_errors=True)
        else:
            tmp = tempfile.mkdtemp(prefix="afrp_")
            try:
                z.extractall(tmp)
                src = os.path.join(tmp, ADDON_NAME)
                if not os.path.isdir(src):
                    src = tmp
                if os.path.isdir(cible):
                    shutil.rmtree(cible)
                if os.path.basename(os.path.normpath(src)) == ADDON_NAME:
                    shutil.copytree(src, cible)
                else:
                    os.makedirs(cible, exist_ok=True)
                    for nom in os.listdir(src):
                        s, d = os.path.join(src, nom), os.path.join(cible, nom)
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


class Pill(tk.Frame):
    def __init__(self, parent, texte, couleur=MUTE):
        super().__init__(parent, bg=CARTE2, highlightbackground=LISERE, highlightthickness=1)
        self.lbl = tk.Label(
            self, text=texte, bg=CARTE2, fg=couleur, font=("Segoe UI Semibold", 9), padx=10, pady=4
        )
        self.lbl.pack()

    def set(self, texte, couleur=MUTE):
        self.lbl.configure(text=texte, fg=couleur)


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(f"AscensionFR Perso  ·  Compagnon {VERSION_COMPAGNON}")
        self.geometry("640x520")
        self.minsize(600, 480)
        self.configure(bg=FOND)
        self.jeu = detecter_jeu()
        self.derniere = None
        self.url_zip = None
        self.notes = ""
        self._appliquer_icone()

        self._chrome()
        self._ui()
        self.after(150, self.verifier)

    def _appliquer_icone(self):
        ico = ressource("assets", "icon.ico")
        png = ressource("assets", "icon.png")
        try:
            if os.path.isfile(ico):
                self.iconbitmap(ico)
        except Exception:
            pass
        try:
            if os.path.isfile(png):
                self._icon_img = tk.PhotoImage(file=png)
                self.iconphoto(True, self._icon_img)
        except Exception:
            pass

    def _chrome(self):
        try:
            self.attributes("-alpha", 0.99)
        except tk.TclError:
            pass

    def _carte(self, parent, **kw):
        f = tk.Frame(
            parent,
            bg=CARTE,
            highlightbackground=LISERE,
            highlightthickness=1,
            padx=kw.get("padx", 18),
            pady=kw.get("pady", 16),
        )
        return f

    def _ui(self):
        shell = tk.Frame(self, bg=FOND)
        shell.pack(fill="both", expand=True, padx=22, pady=22)

        # En-tête
        head = tk.Frame(shell, bg=FOND)
        head.pack(fill="x")
        tk.Label(
            head,
            text="AscensionFR",
            bg=FOND,
            fg=TEXTE,
            font=("Segoe UI", 22, "bold"),
        ).pack(side="left")
        tk.Label(
            head,
            text=" Perso",
            bg=FOND,
            fg=ACCENT,
            font=("Segoe UI", 22, "bold"),
        ).pack(side="left")
        tk.Label(
            head,
            text=f"  compagnon {VERSION_COMPAGNON}",
            bg=FOND,
            fg=MUTE,
            font=("Segoe UI", 10),
        ).pack(side="left", pady=(10, 0))

        tk.Label(
            shell,
            text="Overlay de corrections FR — complète AscensionFR sans jamais l’écraser.",
            bg=FOND,
            fg=MUTE,
            font=("Segoe UI", 10),
            wraplength=580,
            justify="left",
        ).pack(anchor="w", pady=(6, 16))

        # Statut / compatibilité
        row = tk.Frame(shell, bg=FOND)
        row.pack(fill="x", pady=(0, 12))
        self.pill_perso = Pill(row, "Perso …")
        self.pill_perso.pack(side="left", padx=(0, 8))
        self.pill_officiel = Pill(row, "AscensionFR …")
        self.pill_officiel.pack(side="left", padx=(0, 8))
        self.pill_conflit = Pill(row, "Sans conflit", VERT)
        self.pill_conflit.pack(side="left")

        # Carte jeu
        c1 = self._carte(shell)
        c1.pack(fill="x", pady=(0, 12))
        tk.Label(c1, text="DOSSIER DU JEU", bg=CARTE, fg=MUTE, font=("Segoe UI", 8, "bold")).pack(
            anchor="w"
        )
        ligne = tk.Frame(c1, bg=CARTE)
        ligne.pack(fill="x", pady=(8, 0))
        self.var_jeu = tk.StringVar(value=self.jeu)
        ent = tk.Entry(
            ligne,
            textvariable=self.var_jeu,
            bg=CARTE2,
            fg=TEXTE,
            insertbackground=TEXTE,
            relief="flat",
            font=("Segoe UI", 10),
            highlightthickness=1,
            highlightbackground=LISERE,
            highlightcolor=ACCENT,
        )
        ent.pack(side="left", fill="x", expand=True, ipady=7, padx=(0, 8))
        self._btn(ligne, "Parcourir", self.parcourir, secondaire=True).pack(side="left")

        # Carte versions
        c2 = self._carte(shell)
        c2.pack(fill="x", pady=(0, 12))
        tk.Label(c2, text="MISE À JOUR", bg=CARTE, fg=MUTE, font=("Segoe UI", 8, "bold")).pack(
            anchor="w"
        )
        self.lbl_version = tk.Label(
            c2, text="Vérification…", bg=CARTE, fg=TEXTE, font=("Segoe UI", 12, "bold")
        )
        self.lbl_version.pack(anchor="w", pady=(8, 2))
        self.lbl_etat = tk.Label(c2, text="", bg=CARTE, fg=MUTE, font=("Segoe UI", 9), wraplength=560, justify="left")
        self.lbl_etat.pack(anchor="w")

        self.prog = tk.Canvas(c2, height=6, bg=CARTE2, highlightthickness=0)
        self.prog.pack(fill="x", pady=(12, 0))
        self._prog_bar = self.prog.create_rectangle(0, 0, 0, 6, fill=ACCENT, width=0)

        actions = tk.Frame(c2, bg=CARTE)
        actions.pack(fill="x", pady=(14, 0))
        self.btn_maj = self._btn(actions, "Installer / Mettre à jour", self.lancer_maj)
        self.btn_maj.pack(side="left")
        self._btn(actions, "Actualiser", self.verifier, secondaire=True).pack(side="left", padx=(8, 0))
        self._btn(actions, "GitHub", lambda: webbrowser.open(PAGE_RELEASES), secondaire=True).pack(
            side="left", padx=(8, 0)
        )

        # Notes
        c3 = self._carte(shell)
        c3.pack(fill="both", expand=True)
        tk.Label(c3, text="NOTES DE VERSION", bg=CARTE, fg=MUTE, font=("Segoe UI", 8, "bold")).pack(
            anchor="w"
        )
        self.txt_notes = tk.Text(
            c3,
            height=6,
            bg=CARTE2,
            fg=MUTE,
            relief="flat",
            font=("Segoe UI", 9),
            wrap="word",
            highlightthickness=0,
            padx=10,
            pady=8,
        )
        self.txt_notes.pack(fill="both", expand=True, pady=(8, 0))
        self.txt_notes.insert("1.0", "—")
        self.txt_notes.configure(state="disabled")

        pied = tk.Frame(shell, bg=FOND)
        pied.pack(fill="x", pady=(12, 0))
        tk.Label(
            pied,
            text=f"github.com/{DEPOT}  ·  n’écrit que dans AddOns\\{ADDON_NAME}",
            bg=FOND,
            fg=MUTE,
            font=("Segoe UI", 8),
        ).pack(side="left")
        tk.Label(
            pied,
            text="Joue tranquillement — mets à jour après la session.",
            bg=FOND,
            fg=MUTE,
            font=("Segoe UI", 8),
        ).pack(side="right")

    def _btn(self, parent, texte, cmd, secondaire=False):
        if secondaire:
            return tk.Button(
                parent,
                text=texte,
                command=cmd,
                bg=CARTE2,
                fg=TEXTE,
                activebackground=LISERE,
                activeforeground=TEXTE,
                relief="flat",
                font=("Segoe UI Semibold", 9),
                padx=14,
                pady=8,
                cursor="hand2",
                highlightthickness=1,
                highlightbackground=LISERE,
            )
        return tk.Button(
            parent,
            text=texte,
            command=cmd,
            bg=ACCENT,
            fg="#1a1408",
            activebackground=ACCENT2,
            activeforeground="#1a1408",
            relief="flat",
            font=("Segoe UI Semibold", 10),
            padx=18,
            pady=9,
            cursor="hand2",
            borderwidth=0,
        )

    def set_prog(self, ratio):
        self.prog.update_idletasks()
        w = max(self.prog.winfo_width(), 1)
        self.prog.coords(self._prog_bar, 0, 0, int(w * max(0, min(1, ratio))), 6)

    def etat(self, texte, couleur=MUTE):
        self.lbl_etat.configure(text=texte, fg=couleur)

    def set_notes(self, texte):
        self.txt_notes.configure(state="normal")
        self.txt_notes.delete("1.0", "end")
        self.txt_notes.insert("1.0", texte or "Pas de notes pour cette release.")
        self.txt_notes.configure(state="disabled")

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
        self.set_prog(0)
        self.etat("Vérification de la dernière release…", MUTE)

        def travail():
            try:
                derniere, url, notes = derniere_release()
                err = None
            except Exception as e:
                derniere, url, notes, err = None, None, "", str(e)
            self.after(0, lambda: self._apres_verif(derniere, url, notes, err))

        threading.Thread(target=travail, daemon=True).start()

    def _apres_verif(self, derniere, url, notes, err):
        self.derniere, self.url_zip, self.notes = derniere, url, notes
        self.set_notes(notes)

        if not jeu_valide(self.jeu):
            self.lbl_version.configure(text="Choisis le dossier du jeu")
            self.etat("Dossier invalide — cherche le dossier qui contient Interface\\AddOns.", ORANGE)
            self.pill_perso.set("Perso absent", MUTE)
            self.pill_officiel.set("Jeu ?", MUTE)
            self.btn_maj.configure(state="disabled")
            return

        inst = version_installee(self.jeu)
        off = version_installee(self.jeu, OFFICIEL)
        if off:
            self.pill_officiel.set(f"AscensionFR {off}", BLEU)
        else:
            self.pill_officiel.set("AscensionFR absent", ORANGE)

        self.pill_conflit.set("Sans conflit · dossiers séparés", VERT)

        if err:
            self.lbl_version.configure(text=f"Installée : {inst or '—'}")
            self.etat(f"GitHub injoignable : {err}", ROUGE)
            self.pill_perso.set(f"Perso {inst}" if inst else "Perso ?", MUTE)
            self.btn_maj.configure(state="disabled")
            return

        if not inst:
            self.pill_perso.set("Perso non installé", ORANGE)
            self.lbl_version.configure(text=f"Dernière release : {derniere or '?'}")
            self.btn_maj.configure(state="normal", text="Installer AscensionFR Perso")
            self.etat("Prêt — un clic installe l’overlay à côté d’AscensionFR.", VERT)
        elif derniere and en_tuple(derniere) > en_tuple(inst):
            self.pill_perso.set(f"Perso {inst} → {derniere}", ORANGE)
            self.lbl_version.configure(text=f"Mise à jour disponible  ·  {inst}  →  {derniere}")
            self.btn_maj.configure(state="normal", text="Mettre à jour")
            self.etat("Tu peux finir ta session : mets à jour après avoir quitté le jeu.", ORANGE)
        else:
            self.pill_perso.set(f"Perso {inst}", VERT)
            self.lbl_version.configure(text=f"À jour  ·  version {inst}")
            self.btn_maj.configure(state="normal", text="Réinstaller")
            self.etat("Tout est bon. Joue — reviens ici pour les prochaines versions.", VERT)

        if not url:
            self.btn_maj.configure(state="disabled")
            self.etat(f"Asset {ZIP_ATTENDU} manquant sur la release. {PAGE_RELEASES}", ORANGE)

    def lancer_maj(self):
        if not self.url_zip:
            messagebox.showerror("Erreur", "Aucune URL de zip.")
            return
        if not jeu_valide(self.var_jeu.get().strip()):
            messagebox.showerror("Erreur", "Dossier du jeu invalide.")
            return
        self.btn_maj.configure(state="disabled", text="Téléchargement…")
        self.etat("Téléchargement…", MUTE)
        url = self.url_zip
        jeu = self.var_jeu.get().strip()

        def travail():
            try:
                def prog(fait, total):
                    ratio = (fait / total) if total else 0
                    if total:
                        txt = f"Téléchargement… {fait * 100 // total} %"
                    else:
                        txt = f"Téléchargement… {fait / 1048576:.1f} Mo"
                    self.after(0, lambda: (self.etat(txt, MUTE), self.set_prog(ratio or 0.05)))

                chemin = telecharger(url, prog)
                self.after(0, lambda: (self.etat("Installation (Perso uniquement)…", MUTE), self.set_prog(0.92)))
                installer_zip(chemin, jeu)
                cfg = charger_config()
                cfg["jeu"] = jeu
                sauver_config(cfg)
                self.after(0, self._ok)
            except Exception as e:
                self.after(0, lambda: self._fail(str(e)))

        threading.Thread(target=travail, daemon=True).start()

    def _ok(self):
        self.set_prog(1)
        self.etat(
            "Installé. Au prochain login : AddOns → AscensionFR Perso coché, puis /reload (ou relance).",
            VERT,
        )
        self.verifier()

    def _fail(self, msg):
        self.set_prog(0)
        self.etat(msg, ROUGE)
        self.btn_maj.configure(state="normal", text="Réessayer")


if __name__ == "__main__":
    App().mainloop()
