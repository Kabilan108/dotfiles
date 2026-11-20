# ruff: noqa: F401 F821

c = get_config()

c.InteractiveShellApp.extensions = ["autoreload", "icat"]

try:
    import icat

    c.InteractiveShellApp.extensions.append("icat")
except ImportError:
    pass

c.InteractiveShellApp.exec_lines = ["%autoreload 2", "%icat on"]

c.InteractiveShellApp.reraise_ipython_extension_failures = True

c.Application.log_datefmt = "%Y%m%d_%H%M%S"

c.Application.log_format = "[%(name)s] | %(highlevel)s | %(message)s"

c.TerminalIPythonApp.display_banner = False

c.InteractiveShell.colors = "Linux"

c.InteractiveShell.confirm_exit = False

c.TerminalInteractiveShell.editing_mode = "vi"

c.TerminalInteractiveShell.editor = "nvim"

c.TerminalInteractiveShell.enable_history_search = True
