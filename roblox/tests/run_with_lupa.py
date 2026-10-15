"""Führt Lua-Tests mit Lua 5.1 aus, falls kein `lua` installiert ist (pip install lupa).
Aufruf: python3 run_with_lupa.py [planner_test.lua map_test.lua ...]  (ohne Argument: alle *_test.lua)"""
import glob
import os
import sys
from lupa import lua51

here = os.path.dirname(os.path.abspath(__file__))
os.chdir(here)
names = sys.argv[1:] or sorted(glob.glob("*_test.lua"))
for name in names:
    print("== " + name)
    lua51.LuaRuntime().execute(open(name, encoding="utf-8").read())
