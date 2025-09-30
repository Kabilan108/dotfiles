# Configuration file for ipython.
# ruff: noqa: F401 F821

c = get_config()

## list of dotted module names of IPython extensions to load.
c.InteractiveShellApp.extensions = ["autoreload", "icat"]

## lines of code to run at IPython startup.
c.InteractiveShellApp.exec_lines = ["%autoreload 2", "%plt_icat"]

## load icat plugin
try:
    import icat

    c.InteractiveShellApp.extensions.append("icat")
except ImportError:
    pass

## reraise exceptions encountered loading IPython extensions
c.InteractiveShellApp.reraise_ipython_extension_failures = True

## The date format used by logging formatters for %(asctime)s
c.Application.log_datefmt = "%Y%m%d_%H%M%S"

## The Logging format template
c.Application.log_format = "[%(name)s] | %(highlevel)s | %(message)s"

## Whether to display a banner upon starting IPython.
c.TerminalIPythonApp.display_banner = False

## Set the color scheme (NoColor, Neutral, Linux, or LightBG).
c.InteractiveShell.colors = "Linux"

## Set to confirm when you try to exit IPython with an EOF
c.InteractiveShell.confirm_exit = False

## Shortcut style to use at the prompt. 'vi' or 'emacs'.
c.TerminalInteractiveShell.editing_mode = "vi"

## Set the editor used by IPython (default to $EDITOR/vi/notepad).
c.TerminalInteractiveShell.editor = "nvim"

## Allows to enable/disable the prompt toolkit history search
c.TerminalInteractiveShell.enable_history_search = True
