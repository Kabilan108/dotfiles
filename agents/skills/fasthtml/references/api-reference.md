# FastHTML API Reference

Comprehensive API details for FastHTML and MonsterUI. Load this file when you need specific function signatures or advanced usage patterns.

## Core Functions

### fast_app()
```python
fast_app(
    db_file=None,          # Path to SQLite db (creates fastlite db)
    render=None,           # Custom render function
    hdrs=(),               # Headers added to <head>
    ftrs=(),               # Footers added before </body>
    tbls=None,             # Tables to create from db
    before=None,           # Beforeware for auth/middleware
    middleware=None,       # Starlette middleware
    live=False,            # Enable live reload
    debug=False,           # Debug mode
    title="FastHTML",      # Default page title
    pico=True,             # Include Pico CSS
    surreal=True,          # Include Surreal.js
    htmx=True,             # Include HTMX
    exts='',               # HTMX extensions ('ws', 'sse', etc)
    default_hdrs=True,     # Include default headers
    secret_key=None,       # Session secret (auto-generated if None)
    session_cookie='session_',
    static_path='.'        # Static file directory
)
```

### serve()
```python
serve(
    appname=None,          # App module name
    app=None,              # App instance
    host='0.0.0.0',
    port=5001,
    reload=True,           # Auto-reload on changes
    reload_includes=None,
    reload_excludes=None
)
```

## Route Handlers

### Decorator Patterns
```python
@rt                        # Route = function name, GET+POST
@rt("/custom/path")        # Custom path
@rt("/item/{id}")          # Path parameter
@rt("/{fname:path}.{ext:static}")  # Static files

# Methods
@rt("/api", methods=["GET"])
@rt("/api", methods=["POST"])
```

### Parameter Sources (in order of precedence)
1. Path parameters: `/item/{id}` → `def handler(id: int)`
2. Query parameters: `?name=x` → `def handler(name: str)`
3. Cookies: `def handler(session_cookie: str)`
4. Headers: `def handler(x_custom: str)`
5. Session: `def handler(sess)`
6. Form data: `def handler(form_field: str)`

### Special Parameters
```python
def handler(
    req,              # Starlette Request
    sess,             # Session dict
    auth,             # scope['auth'] (set by Beforeware)
    htmx,             # HtmxHeaders dataclass
    app               # FastHTML app instance
): ...
```

### Type Coercion
```python
def handler(id: int): ...              # Auto-converted
def handler(active: bool): ...         # "true"/"1" → True
def handler(items: list[int]): ...     # Multiple values
def handler(user: User): ...           # Dataclass from form
```

## FastTags Reference

### HTML Elements
All standard HTML tags available: `Div`, `P`, `H1`-`H6`, `A`, `Span`, `Input`, `Button`, `Form`, `Table`, `Tr`, `Td`, `Th`, `Ul`, `Li`, `Nav`, `Main`, `Header`, `Footer`, `Section`, `Article`, etc.

### Attribute Mapping
```python
cls="x"      → class="x"
_for="x"     → for="x"
fr="x"       → for="x"
hx_get="x"   → hx-get="x"
data_id="x"  → data-id="x"
```

### Extended Tags
```python
# A with default href="#"
A("Link", hx_get=handler)

# AX: (text, hx_get, target_id, hx_swap, href)
AX("Load", load_data, "content")

# Form with multipart/form-data encoding
Form(method="post", action=handler)(*fields)

# Hidden input
Hidden(value="x", id="hidden_field")

# Checkbox with hidden fallback for false values
CheckboxX(id="active", label="Active", checked=True)

# Script that doesn't escape content
Script("console.log('hi');")

# Style that doesn't escape content
Style("body { margin: 0; }")
```

### Titled Helper
```python
Titled("Page Title", *children, **kwargs)
# Returns: (Title("Page Title"), Container(H1("Page Title"), *children))
```

## Pico CSS Components

```python
# Card with optional header/footer
Card(*content, header=H3("Title"), footer=Button("Action"))

# Grid layout
Grid(Div("A"), Div("B"), Div("C"))  # Auto columns

# Search form
Search(Input(type="search"), Button("Search"))

# Group inputs inline
Group(Input(name="first"), Input(name="last"))

# Container
Container(*content)  # <main class="container">
```

## HTMX Attributes

### Core
```python
hx_get="/path"           # GET request
hx_post="/path"          # POST request
hx_put="/path"           # PUT request
hx_delete="/path"        # DELETE request
hx_patch="/path"         # PATCH request
```

### Targeting & Swapping
```python
hx_target="#id"          # Target element
hx_target="this"         # Triggering element
hx_target="closest div"  # Closest ancestor
hx_target="find .class"  # Descendant
hx_target="next"         # Next sibling
hx_target="previous"     # Previous sibling

hx_swap="innerHTML"      # Replace inner HTML (default)
hx_swap="outerHTML"      # Replace entire element
hx_swap="beforebegin"    # Before element
hx_swap="afterbegin"     # First child
hx_swap="beforeend"      # Last child
hx_swap="afterend"       # After element
hx_swap="delete"         # Remove element
hx_swap="none"           # No swap

hx_swap_oob="true"       # Out-of-band swap by id
```

### Triggers
```python
hx_trigger="click"                    # On click (default for buttons)
hx_trigger="change"                   # On change (default for inputs)
hx_trigger="submit"                   # On form submit
hx_trigger="load"                     # On element load
hx_trigger="revealed"                 # When scrolled into view
hx_trigger="every 2s"                 # Polling
hx_trigger="keyup changed delay:500ms"  # Debounced
hx_trigger="click once"               # Only once
hx_trigger="click throttle:1s"        # Throttled
```

### Other Attributes
```python
hx_confirm="Are you sure?"    # Confirmation dialog
hx_indicator="#spinner"       # Loading indicator
hx_disabled_elt="this"        # Disable during request
hx_vals='{"key": "value"}'    # Additional values
hx_include="#form"            # Include other elements
hx_push_url="true"            # Update browser URL
hx_select="#part"             # Select part of response
```

## Fastlite Database

### Setup
```python
from fastlite import database

db = database('app.db')  # or ':memory:'

class Item: id:int; name:str; active:bool=True; created:str
items = db.create(Item, pk='id', transform=True)
```

### CRUD Operations
```python
# Create
item = items.insert(name="Test", active=True)
items.insert(Item(name="Test"))

# Read
items()                           # All records
items[1]                          # By primary key
items(where="active=1")           # Filter
items("name=?", ("Test",))        # Parameterized
items(order_by='name')            # Sort
items(limit=10, offset=20)        # Paginate

# Update
items.update({'name': 'New'}, id=1)
items.update(item)                # Update object

# Delete
items.delete(1)                   # By primary key

# Exists check
1 in items                        # True/False

# Filter all subsequent queries
items.xtra(active=True)           # Only active items
```

## MonsterUI Components

### Theme Setup
```python
from monsterui.all import *

app, rt = fast_app(hdrs=Theme.blue.headers())
# Themes: slate, stone, gray, neutral, red, rose, orange, green, blue, yellow, violet, zinc
# Options: Theme.blue.headers(highlightjs=True, katex=True)
```

### Layout Components
```python
# Grid with columns
Grid(*items, cols=3)               # Fixed columns
Grid(*items)                       # Auto columns

# Flex layouts
DivFullySpaced(left, right)        # Space between
DivCentered(*items)                # Centered
DivLAligned(*items)                # Left aligned
DivRAligned(*items)                # Right aligned
DivVStacked(*items)                # Vertical stack
DivHStacked(*items)                # Horizontal stack

# Container
Container(*content, cls=ContainerT.lg)
```

### Cards
```python
Card(*body, header=None, footer=None, cls=CardT.default)
# CardT: default, primary, secondary, destructive, hover

CardHeader(*content)
CardBody(*content)
CardFooter(*content)
CardTitle("Title")
```

### Typography
```python
H1("Heading")  # H1-H6 with styling
P("Paragraph", cls=TextPresets.muted_sm)

# TextPresets: muted_sm, muted_lg, bold_sm, bold_lg, md_weight_sm, md_weight_muted
Strong("Bold")
Em("Italic")
Mark("Highlighted")
Blockquote(P("Quote"), Cite("Author"))
```

### Forms
```python
Form(*fields, cls="space-y-4")
Input(id="name", placeholder="Name")
TextArea(id="desc", rows=5)
Select(*[Option(x, value=x) for x in options])
CheckboxX(id="active", label="Active")
Radio(name="choice", value="a")
Range(id="vol", min=0, max=100)
Switch(id="toggle")

# Label + Input pairs
LabelInput("Email", id="email", type="email")
LabelSelect("Country", *options, id="country")
LabelCheckboxX("Active", id="active")
LabelRange("Volume", id="vol", min=0, max=100)
```

### Buttons
```python
Button("Click", cls=ButtonT.primary)
# ButtonT: default, ghost, primary, secondary, destructive, text, link, xs, sm, lg, xl, icon

LoaderButton("Submit")  # Shows spinner during HTMX request
```

### Tables
```python
Table(
    Thead(Tr(Th("Col1"), Th("Col2"))),
    Tbody(Tr(Td("A"), Td("B")), Tr(Td("C"), Td("D"))),
    cls=TableT.striped)
# TableT: divider, striped, hover, sm, lg, responsive

# From data
TableFromLists(["A", "B"], [["1", "2"], ["3", "4"]])
TableFromDicts(["name", "age"], [{"name": "X", "age": 1}])
```

### Navigation
```python
NavBar(
    A("Home", href=index),
    A("About", href=about),
    A("Contact", href=contact))

NavContainer(
    Li(A("Dashboard", href=index)),
    NavDividerLi(),
    NavHeaderLi("Settings"),
    Li(A("Profile", href=profile)))

TabContainer(
    Li(A("Tab 1", href="#")),
    Li(A("Tab 2", href="#")))
```

### Modals
```python
Modal(
    ModalHeader(ModalTitle("Title")),
    ModalBody(P("Content")),
    ModalFooter(Button("Close", cls="uk-modal-close")),
    id="my-modal")

# Open with: Button("Open", uk_toggle="target: #my-modal")
```

### Alerts & Messages
```python
Alert("Message", cls=AlertT.success)
# AlertT: info, success, warning, error
```

### Icons
```python
UkIcon("home", height=24)
UkIconLink("github", href="https://github.com")
DiceBearAvatar("username", h=48, w=48)
```

### Progress & Loading
```python
Progress(value=75, max=100)
Loading(cls=LoadingT.spinner)
# LoadingT: spinner, dots, ring, ball, bars, infinity
```

### Utility
```python
Divider()                          # Horizontal line
DividerSplit("OR")                 # Line with text
Placeholder("Content goes here")   # Placeholder box
render_md("**Markdown** content")  # Render markdown
```

## WebSockets

```python
app, rt = fast_app(exts='ws')

@rt
def index():
    return Titled("Chat",
        Div(id="messages"),
        Form(Input(id="msg"), id="form", ws_send=True,
             hx_ext="ws", ws_connect="/ws"))

async def on_connect(send):
    await send(Div("Connected", id="messages"))

@app.ws('/ws', conn=on_connect)
async def ws(msg: str, send):
    await send(Div(f"You said: {msg}", id="messages"))
```

## Authentication Pattern

```python
def auth_before(req, sess):
    auth = req.scope['auth'] = sess.get('auth')
    if not auth: return RedirectResponse('/login', status_code=303)

bware = Beforeware(auth_before, skip=['/login', '/static/.*'])
app, rt = fast_app(before=bware)

@rt
def login():
    return Titled("Login",
        Form(action=do_login, method="post")(
            Input(name="user", placeholder="Username"),
            Input(name="pwd", type="password"),
            Button("Login")))

@rt
def do_login(user: str, pwd: str, sess):
    if validate(user, pwd):
        sess['auth'] = user
        return RedirectResponse('/', status_code=303)
    return login()

@rt
def logout(sess):
    del sess['auth']
    return RedirectResponse('/login', status_code=303)
```

## File Uploads

```python
from starlette.datastructures import UploadFile

@rt
def upload_form():
    return Form(hx_post=upload, hx_target="#result")(
        Input(type="file", name="file"),
        Button("Upload"))

@rt
async def upload(file: UploadFile):
    content = await file.read()
    Path(f"uploads/{file.filename}").write_bytes(content)
    return P(f"Uploaded: {file.filename} ({file.size} bytes)")
```

## Response Types

```python
# FT components → HTML
return Div("Hello")

# Tuple → concatenated HTML
return Title("Page"), H1("Hello")

# Dict/list → JSON
return {"status": "ok"}

# Starlette responses
return RedirectResponse('/other', status_code=303)
return FileResponse('file.pdf')
return JSONResponse({"data": value})
return HTMLResponse("<h1>Raw HTML</h1>")

# FtResponse for custom status/headers
return FtResponse(Div("Error"), status_code=400)
```

## Testing

```python
from starlette.testclient import TestClient

client = TestClient(app)

# Regular request
resp = client.get('/')
assert resp.status_code == 200

# HTMX request
resp = client.get('/partial', headers={'HX-Request': '1'})
assert '<div>' in resp.text

# Form submission
resp = client.post('/submit', data={'name': 'Test'})
```
