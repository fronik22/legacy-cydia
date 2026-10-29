from pathlib import Path
import sys
R=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(R.parent/"localsend/packaging"))
from ipa_package import build
if len(sys.argv)!=2:raise SystemExit("Usage: package-cydia.py Troubadour-1.6.447.ipa")
build(R,sys.argv[1],"local.codex.troubadour-installer","ru.computershik.troubadour","1.6.447","Troubadour",["Troubadour"],R/"LICENSE")
