from pathlib import Path
import sys
from ipa_package import build
R=Path(__file__).resolve().parents[1]
if len(sys.argv)!=2:raise SystemExit("Usage: package_cydia.py LocalSend-5.7.4340.ipa")
build(R,sys.argv[1],"local.codex.localsend-installer","com.unlocalsend.ios6","5.7.4340","LocalSend",["LocalSend6","LocalSend"],R/"LICENSE")
