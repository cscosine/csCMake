"""The licences of the third-party files in the built documentation, for its Licences page (``docs/licences.md``).

The HTML documentation (the site and ``csCMake-docs-<version>.zip``) contains files of the tools that build it: the
Sphinx search and base styles, the Furo theme, the sphinx-design styles, the Pygments highlighting styles, and the
Snowball stemmer of the Sphinx search. Their licences ask to reproduce their notices: ``docs/conf.py`` puts the text
returned here in the Licences page. The licence texts come from the installed packages (the versions that built the
documentation); Snowball's is not in any of them (Sphinx ships its generated JavaScript), it is kept here.
"""

from __future__ import annotations

from importlib import metadata

# (name shown, distribution name) of the packages whose files are in the built documentation
DOCUMENTATION_PACKAGES = (
    ("Sphinx", "sphinx"),
    ("Furo", "furo"),
    ("sphinx-design", "sphinx-design"),
    ("Pygments", "pygments"),
)

# https://github.com/snowballstem/snowball/blob/master/COPYING
SNOWBALL_LICENCE = """\
Copyright (c) 2001, Dr Martin Porter
Copyright (c) 2004,2005, Richard Boulton
Copyright (c) 2013, Yoshiki Shibukawa
Copyright (c) 2006-2025, Olly Betts
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

  1. Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.
  2. Redistributions in binary form must reproduce the above copyright notice,
     this list of conditions and the following disclaimer in the documentation
     and/or other materials provided with the distribution.
  3. Neither the name of the Snowball project nor the names of its contributors
     may be used to endorse or promote products derived from this software
     without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
"""


def licence_text(distribution: str) -> str:
    """Return the licence file of an installed distribution (``LICENSE``, ``licenses/LICENSE.rst``, ...)."""
    files = [file for file in metadata.files(distribution) or [] if "licen" in file.name.lower()]
    if not files:
        raise LookupError(f"no licence file in the installed distribution {distribution}")
    return files[0].read_text(encoding="utf-8").strip() + "\n"


def third_party_licences_markdown() -> str:
    """Return the licence of each third-party package of the built documentation, as Markdown sections."""
    sections = [
        (f"{name} {metadata.version(distribution)}", licence_text(distribution))
        for name, distribution in DOCUMENTATION_PACKAGES
    ]
    sections.append(("Snowball (the English stemmer of the Sphinx search)", SNOWBALL_LICENCE))
    return "".join(f"### {title}\n\n```text\n{text}```\n\n" for title, text in sections)
