---
name: fasthtml
description: Build interactive web apps in pure Python using FastHTML. Use when the user wants to prototype web apps in Python without JavaScript frameworks. FastHTML combines HTMX for interactivity, Starlette for routing, and Python "FastTags" for HTML generation. Ideal for rapid prototyping with real-time updates, forms, charts, and database-backed UIs.
---

# FastHTML Dashboard Development

FastHTML creates server-rendered hypermedia apps in pure Python. It combines Starlette (routing), HTMX (interactivity), and FastTags (HTML generation).

**Key principles:**
- Prefer Python over JS; never use React/Vue/Svelte
- Use `serve()` to run (no `if __name__` needed)
- Return FT components or tuples from handlers
- Use HTMX attributes for dynamic updates without page reloads

## Minimal App

```python
from fasthtml.common import *

app, rt = fast_app()

@rt
def index():
    return Titled("Dashboard", 
        P("Welcome to the dashboard"),
        A("View Data", hx_get=data, hx_target="#content"),
        Div(id="content"))

@rt
def data():
    return Div(H2("Data Loaded"), P("Dynamic content here"))

serve()
```

Run: `python app.py` → Access at `localhost:5001`

## FastTags (FT Components)

HTML elements as Python functions. Positional args = children, keyword args = attributes.

```python
# Basic elements
Div(P("Hello"), cls="container")  # cls → class
Input(id="email", type="email", placeholder="Email")
Button("Submit", type="submit", disabled=False)  # False omits attr

# Special attributes
Label("Name", _for="name")  # _for → for
Div(**{'@click': "handler()"})  # dict unpacking for special chars

# Common patterns
Form(method="post", action=handler)(
    Input(name="title", placeholder="Title"),
    Button("Save"))
```

## HTMX Interactivity

Add `hx_*` attributes for dynamic behavior without JavaScript:

```python
# GET request, swap inner HTML of #results
Button("Load", hx_get=search, hx_target="#results")

# POST form, swap response into #items after existing content
Form(hx_post=create, hx_target="#items", hx_swap="beforeend")(
    Input(name="item"), Button("Add"))

# Common hx_swap values: innerHTML (default), outerHTML, beforeend, afterbegin, delete
# Trigger on events: hx_trigger="click", "change", "keyup delay:500ms"
```

## Dashboard Layout Pattern

```python
from fasthtml.common import *

app, rt = fast_app()

def nav(): 
    return Nav(
        A("Dashboard", href=index), 
        A("Reports", href=reports),
        A("Settings", href=settings))

def layout(*content, title="Dashboard"):
    return Title(title), Container(nav(), Main(*content))

@rt
def index():
    return layout(
        H1("Overview"),
        Grid(
            Card(H3("Users"), P("1,234"), header=None, footer=A("View all", href=users)),
            Card(H3("Revenue"), P("$45,678")),
            Card(H3("Orders"), P("89"))),
        title="Dashboard")
```

## Database-Backed Dashboard (Fastlite)

```python
from fasthtml.common import *
from fastlite import database

db = database('dashboard.db')

class Metric: id:int; name:str; value:float; updated:str
metrics = db.create(Metric, transform=True)

app, rt = fast_app()

@rt
def index():
    return Titled("Metrics Dashboard",
        Div(id="metrics-list")(*[metric_card(m) for m in metrics()]),
        Form(hx_post=add_metric, hx_target="#metrics-list", hx_swap="beforeend")(
            Input(name="name", placeholder="Metric name"),
            Input(name="value", type="number", placeholder="Value"),
            Button("Add Metric")))

def metric_card(m):
    return Card(H4(m.name), P(f"{m.value}"), id=f"metric-{m.id}",
        footer=Button("Delete", hx_post=delete.to(id=m.id), 
                      hx_target=f"#metric-{m.id}", hx_swap="outerHTML"))

@rt
def add_metric(metric: Metric):
    return metric_card(metrics.insert(metric))

@rt
def delete(id: int):
    metrics.delete(id)
    return ""  # Empty response removes element

serve()
```

## Charts with Plotly

```python
app, rt = fast_app(hdrs=[Script(src="https://cdn.plot.ly/plotly-2.32.0.min.js")])

@rt
def index():
    data = [{"x": [1,2,3], "y": [4,1,2], "type": "scatter"}]
    return Titled("Chart Dashboard",
        Div(id="chart"),
        Script(f"Plotly.newPlot('chart', {data});"))
```

## Real-Time Updates (SSE)

```python
from fasthtml.common import *
import asyncio

hdrs = (Script(src="https://unpkg.com/htmx-ext-sse@2.2.3/sse.js"),)
app, rt = fast_app(hdrs=hdrs)
shutdown = signal_shutdown()

@rt
def index():
    return Titled("Live Dashboard",
        Div(hx_ext="sse", sse_connect="/stream", sse_swap="message", 
            hx_swap="innerHTML", id="live-data"))

async def generate():
    import random
    while not shutdown.is_set():
        yield sse_message(Div(f"Value: {random.randint(1,100)}"))
        await asyncio.sleep(1)

@rt
async def stream(): return EventStream(generate())

serve()
```

## Forms and Data Binding

```python
from dataclasses import dataclass

@dataclass
class Settings: theme:str; notifications:bool; limit:int

@rt
def settings():
    form = Form(hx_post=save_settings)(
        LabelInput("Theme", name="theme"),
        CheckboxX(id="notifications", label="Enable notifications"),
        LabelInput("Limit", name="limit", type="number"),
        Button("Save"))
    return Titled("Settings", fill_form(form, current_settings))

@rt
def save_settings(s: Settings):
    # s is auto-populated from form data
    save_to_db(s)
    return Div("Settings saved!", id="message")
```

## MonsterUI for Rich Dashboards

For production dashboards with Tailwind styling, use MonsterUI:

```python
from fasthtml.common import *
from monsterui.all import *

app, rt = fast_app(hdrs=Theme.blue.headers())

@rt
def index():
    return Titled("Dashboard",
        Grid(
            Card(H3("Metric 1"), P("$12,345", cls=TextPresets.bold_lg)),
            Card(H3("Metric 2"), P("1,234 users")),
            Card(H3("Metric 3"), P("98.5%")), cols=3),
        Card(
            CardHeader(H3("Recent Activity")),
            CardBody(
                Table(
                    Thead(Tr(Th("User"), Th("Action"), Th("Time"))),
                    Tbody(
                        Tr(Td("Alice"), Td("Login"), Td("2m ago")),
                        Tr(Td("Bob"), Td("Purchase"), Td("5m ago")))))))

serve()
```

MonsterUI provides: `Card`, `Grid`, `Table`, `Button` (with `ButtonT.primary/destructive`), `Modal`, `NavBar`, `DivFullySpaced`, `DivCentered`, `LabelInput`, `LabelSelect`, form components, and typography presets.

## Common Patterns Reference

| Pattern | Code |
|---------|------|
| Target by ID | `hx_target="#element-id"` |
| Swap modes | `hx_swap="outerHTML"`, `"beforeend"`, `"afterbegin"`, `"delete"` |
| OOB update | `Div(id="x", hx_swap_oob="true")` updates #x regardless of target |
| Route as href | `A("Link", href=handler)` or `hx_get=handler` |
| With params | `handler.to(id=5)` → `/handler?id=5` |
| Confirm action | `hx_confirm="Are you sure?"` |
| Loading indicator | `hx_indicator="#spinner"` |
| Debounce input | `hx_trigger="keyup changed delay:500ms"` |

## File Structure

```
my_dashboard/
├── main.py          # App entry point
├── data/
│   └── app.db       # SQLite database
└── static/          # Static files (auto-served)
    └── styles.css
```

## Quick Reference

- `fast_app()` - Create app with sensible defaults (includes Pico CSS)
- `fast_app(pico=False, hdrs=[...])` - Custom headers, no Pico
- `Titled(title, *children)` - Page with Title + H1 + Container
- `Card(*c, header=, footer=)` - Card component
- `Grid(*divs)` - CSS grid layout
- `fill_form(form, obj)` - Populate form from object
- `serve()` - Run uvicorn with live reload

For comprehensive API details, see references/api-reference.md.
