"""Führt planner_test.lua mit Lua 5.1 aus, falls kein `lua` installiert ist (pip install lupa)."""
import os
from lupa import lua51

here = os.path.dirname(os.path.abspath(__file__))
os.chdir(here)
lua = lua51.LuaRuntime()
with open("planner_test.lua", encoding="utf-8") as f:
    lua.execute(f.read())
