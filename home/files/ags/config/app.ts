#!/usr/bin/gjs -m
/**
 * © 2025 Demeter Kristóf <k.demeter@protonmail.com>
 */
var __defProp = Object.defineProperty
var __getOwnPropDesc = Object.getOwnPropertyDescriptor
var __getOwnPropNames = Object.getOwnPropertyNames
var __typeError = (msg) => {
  throw TypeError(msg)
}
var __defNormalProp = (obj, key, value) => (key in obj ? __defProp(obj, key, { enumerable: true, configurable: true, writable: true, value: value }) : (obj[key] = value))
var __esm = (fn, res) =>
  function __init() {
    return fn && (res = (0, fn[__getOwnPropNames(fn)[0]])((fn = 0))), res
  }
var __export = (target, all) => {
  for (var name in all) __defProp(target, name, { get: all[name], enumerable: true })
}
var __decorateClass = (decorators, target, key, kind) => {
  var result = kind > 1 ? void 0 : kind ? __getOwnPropDesc(target, key) : target
  for (var i = decorators.length - 1, decorator; i >= 0; i--) if ((decorator = decorators[i])) result = (kind ? decorator(target, key, result) : decorator(result)) || result
  if (kind && result) __defProp(target, key, result)
  return result
}
var __publicField = (obj, key, value) => __defNormalProp(obj, typeof key !== "symbol" ? key + "" : key, value)
var __accessCheck = (obj, member, msg) => member.has(obj) || __typeError("Cannot " + msg)
var __privateGet = (obj, member, getter) => (__accessCheck(obj, member, "read from private field"), getter ? getter.call(obj) : member.get(obj))
var __privateAdd = (obj, member, value) => (member.has(obj) ? __typeError("Cannot add the same private member more than once") : member instanceof WeakSet ? member.add(obj) : member.set(obj, value))
var __privateSet = (obj, member, value, setter) => (__accessCheck(obj, member, "write to private field"), setter ? setter.call(obj, value) : member.set(obj, value), value)
async function suppress(mod, patch2) {
  return mod.then((m) => patch2(m.default)).catch(() => void 0)
}
function patch(proto, prop) {
  Object.defineProperty(proto, prop, {
    get() {
      return this[`get_${snakeify(prop)}`]()
    },
  })
}
var snakeify
var init_overrides = __esm({
  async "../../../../nix/store/zqn3hxrlyyg9mkd267g0dvxa5rrcrd0c-astal-gjs/share/astal/gjs/overrides.ts"() {
    snakeify = (str) =>
      str
        .replace(/([a-z])([A-Z])/g, "$1_$2")
        .replaceAll("-", "_")
        .toLowerCase()
    await suppress(import("gi://AstalApps"), ({ Apps: Apps4, Application }) => {
      patch(Apps4.prototype, "list")
      patch(Application.prototype, "keywords")
      patch(Application.prototype, "categories")
    })
    await suppress(import("gi://AstalBattery"), ({ UPower }) => {
      patch(UPower.prototype, "devices")
    })
    await suppress(import("gi://AstalBluetooth"), ({ Adapter, Bluetooth: Bluetooth4, Device: Device2 }) => {
      patch(Adapter.prototype, "uuids")
      patch(Bluetooth4.prototype, "adapters")
      patch(Bluetooth4.prototype, "devices")
      patch(Device2.prototype, "uuids")
    })
    await suppress(import("gi://AstalHyprland"), ({ Hyprland: Hyprland6, Monitor, Workspace: Workspace2 }) => {
      patch(Hyprland6.prototype, "monitors")
      patch(Hyprland6.prototype, "workspaces")
      patch(Hyprland6.prototype, "clients")
      patch(Monitor.prototype, "availableModes")
      patch(Monitor.prototype, "available_modes")
      patch(Workspace2.prototype, "clients")
    })
    await suppress(import("gi://AstalMpris"), ({ Mpris: Mpris5, Player: Player2 }) => {
      patch(Mpris5.prototype, "players")
      patch(Player2.prototype, "supported_uri_schemes")
      patch(Player2.prototype, "supportedUriSchemes")
      patch(Player2.prototype, "supported_mime_types")
      patch(Player2.prototype, "supportedMimeTypes")
      patch(Player2.prototype, "comments")
    })
    await suppress(import("gi://AstalNetwork"), ({ Wifi: Wifi2 }) => {
      patch(Wifi2.prototype, "access_points")
      patch(Wifi2.prototype, "accessPoints")
    })
    await suppress(import("gi://AstalNotifd"), ({ Notifd: Notifd8, Notification: Notification3 }) => {
      patch(Notifd8.prototype, "notifications")
      patch(Notification3.prototype, "actions")
    })
    await suppress(import("gi://AstalPowerProfiles"), ({ PowerProfiles: PowerProfiles2 }) => {
      patch(PowerProfiles2.prototype, "actions")
    })
    await suppress(import("gi://AstalWp"), ({ Wp: Wp5, Audio, Video }) => {
      patch(Wp5.prototype, "endpoints")
      patch(Wp5.prototype, "devices")
      patch(Audio.prototype, "streams")
      patch(Audio.prototype, "recorders")
      patch(Audio.prototype, "microphones")
      patch(Audio.prototype, "speakers")
      patch(Audio.prototype, "devices")
      patch(Video.prototype, "streams")
      patch(Video.prototype, "recorders")
      patch(Video.prototype, "sinks")
      patch(Video.prototype, "sources")
      patch(Video.prototype, "devices")
    })
  },
})
import { setConsoleLogDomain } from "console"
import { exit, programArgs } from "system"
import IO from "gi://AstalIO"
import GObject from "gi://GObject"
function mkApp(App) {
  return new (class AstalJS extends App {
    static {
      GObject.registerClass({ GTypeName: "AstalJS" }, this)
    }
    eval(body) {
      return new Promise((res, rej) => {
        try {
          const fn = Function(`return (async function() {
                        ${body.includes(";") ? body : `return ${body};`}
                    })`)
          fn()().then(res).catch(rej)
        } catch (error) {
          rej(error)
        }
      })
    }
    requestHandler
    vfunc_request(msg, conn) {
      if (typeof this.requestHandler === "function") {
        this.requestHandler(msg, (response) => {
          IO.write_sock(conn, String(response), (_, res) => IO.write_sock_finish(res))
        })
      } else {
        super.vfunc_request(msg, conn)
      }
    }
    apply_css(style, reset3 = false) {
      super.apply_css(style, reset3)
    }
    quit(code) {
      super.quit()
      exit(code ?? 0)
    }
    start({ requestHandler, css, hold, main: main2, client, icons: icons2, ...cfg } = {}) {
      const app = this
      client ??= () => {
        print(`Astal instance "${app.instanceName}" already running`)
        exit(1)
      }
      Object.assign(this, cfg)
      setConsoleLogDomain(app.instanceName)
      this.requestHandler = requestHandler
      app.connect("activate", () => {
        main2?.(...programArgs)
      })
      try {
        app.acquire_socket()
      } catch (error) {
        return client((msg) => IO.send_message(app.instanceName, msg), ...programArgs)
      }
      if (css) this.apply_css(css, false)
      if (icons2) app.add_icons(icons2)
      hold ??= true
      if (hold) app.hold()
      app.runAsync([])
    }
  })()
}
var init_app = __esm({
  async "../../../../nix/store/zqn3hxrlyyg9mkd267g0dvxa5rrcrd0c-astal-gjs/share/astal/gjs/_app.ts"() {
    await init_overrides()
  },
})
import Gtk2 from "gi://Gtk?version=3.0"
import Astal from "gi://Astal?version=3.0"
var app_default
var init_app2 = __esm({
  async "../../../../nix/store/zqn3hxrlyyg9mkd267g0dvxa5rrcrd0c-astal-gjs/share/astal/gjs/gtk3/app.ts"() {
    await init_app()
    Gtk2.init(null)
    app_default = mkApp(Astal.Application)
  },
})
var snakeify2, kebabify, Binding, bind, binding_default
var init_binding = __esm({
  "../../../../nix/store/zqn3hxrlyyg9mkd267g0dvxa5rrcrd0c-astal-gjs/share/astal/gjs/binding.ts"() {
    snakeify2 = (str) =>
      str
        .replace(/([a-z])([A-Z])/g, "$1_$2")
        .replaceAll("-", "_")
        .toLowerCase()
    kebabify = (str) =>
      str
        .replace(/([a-z])([A-Z])/g, "$1-$2")
        .replaceAll("_", "-")
        .toLowerCase()
    Binding = class _Binding {
      transformFn = (v) => v
      #emitter
      #prop
      static bind(emitter, prop) {
        return new _Binding(emitter, prop)
      }
      constructor(emitter, prop) {
        this.#emitter = emitter
        this.#prop = prop && kebabify(prop)
      }
      toString() {
        return `Binding<${this.#emitter}${this.#prop ? `, "${this.#prop}"` : ""}>`
      }
      as(fn) {
        const bind2 = new _Binding(this.#emitter, this.#prop)
        bind2.transformFn = (v) => fn(this.transformFn(v))
        return bind2
      }
      get() {
        if (typeof this.#emitter.get === "function") return this.transformFn(this.#emitter.get())
        if (typeof this.#prop === "string") {
          const getter = `get_${snakeify2(this.#prop)}`
          if (typeof this.#emitter[getter] === "function") return this.transformFn(this.#emitter[getter]())
          return this.transformFn(this.#emitter[this.#prop])
        }
        throw Error("can not get value of binding")
      }
      subscribe(callback) {
        if (typeof this.#emitter.subscribe === "function") {
          return this.#emitter.subscribe(() => {
            callback(this.get())
          })
        } else if (typeof this.#emitter.connect === "function") {
          const signal2 = `notify::${this.#prop}`
          const id = this.#emitter.connect(signal2, () => {
            callback(this.get())
          })
          return () => {
            this.#emitter.disconnect(id)
          }
        }
        throw Error(`${this.#emitter} is not bindable`)
      }
    }
    ;({ bind } = Binding)
    binding_default = Binding
  },
})
import Astal2 from "gi://AstalIO"
function interval(interval2, callback) {
  return Astal2.Time.interval(interval2, () => void callback?.())
}
function timeout(timeout2, callback) {
  return Astal2.Time.timeout(timeout2, () => void callback?.())
}
function idle(callback) {
  return Astal2.Time.idle(() => void callback?.())
}
var Time
var init_time = __esm({
  "../../../../nix/store/zqn3hxrlyyg9mkd267g0dvxa5rrcrd0c-astal-gjs/share/astal/gjs/time.ts"() {
    Time = Astal2.Time
  },
})
import Astal3 from "gi://AstalIO"
function subprocess(argsOrCmd, onOut = print, onErr = printerr) {
  const args = Array.isArray(argsOrCmd) || typeof argsOrCmd === "string"
  const { cmd, err, out } = { cmd: args ? argsOrCmd : argsOrCmd.cmd, err: args ? onErr : argsOrCmd.err || onErr, out: args ? onOut : argsOrCmd.out || onOut }
  const proc = Array.isArray(cmd) ? Astal3.Process.subprocessv(cmd) : Astal3.Process.subprocess(cmd)
  proc.connect("stdout", (_, stdout) => out(stdout))
  proc.connect("stderr", (_, stderr) => err(stderr))
  return proc
}
function exec(cmd) {
  return Array.isArray(cmd) ? Astal3.Process.execv(cmd) : Astal3.Process.exec(cmd)
}
function execAsync(cmd) {
  return new Promise((resolve, reject) => {
    if (Array.isArray(cmd)) {
      Astal3.Process.exec_asyncv(cmd, (_, res) => {
        try {
          resolve(Astal3.Process.exec_asyncv_finish(res))
        } catch (error) {
          reject(error)
        }
      })
    } else {
      Astal3.Process.exec_async(cmd, (_, res) => {
        try {
          resolve(Astal3.Process.exec_finish(res))
        } catch (error) {
          reject(error)
        }
      })
    }
  })
}
var Process
var init_process = __esm({
  "../../../../nix/store/zqn3hxrlyyg9mkd267g0dvxa5rrcrd0c-astal-gjs/share/astal/gjs/process.ts"() {
    Process = Astal3.Process
  },
})
import Astal4 from "gi://AstalIO"
var VariableWrapper, Variable, derive, variable_default
var init_variable = __esm({
  "../../../../nix/store/zqn3hxrlyyg9mkd267g0dvxa5rrcrd0c-astal-gjs/share/astal/gjs/variable.ts"() {
    init_binding()
    init_time()
    init_process()
    VariableWrapper = class extends Function {
      variable
      errHandler = console.error
      _value
      _poll
      _watch
      pollInterval = 1e3
      pollExec
      pollTransform
      pollFn
      watchTransform
      watchExec
      constructor(init3) {
        super()
        this._value = init3
        this.variable = new Astal4.VariableBase()
        this.variable.connect("dropped", () => {
          this.stopWatch()
          this.stopPoll()
        })
        this.variable.connect("error", (_, err) => this.errHandler?.(err))
        return new Proxy(this, { apply: (target, _, args) => target._call(args[0]) })
      }
      _call(transform) {
        const b = binding_default.bind(this)
        return transform ? b.as(transform) : b
      }
      toString() {
        return String(`Variable<${this.get()}>`)
      }
      get() {
        return this._value
      }
      set(value) {
        if (value !== this._value) {
          this._value = value
          this.variable.emit("changed")
        }
      }
      startPoll() {
        if (this._poll) return
        if (this.pollFn) {
          this._poll = interval(this.pollInterval, () => {
            const v = this.pollFn(this.get())
            if (v instanceof Promise) {
              v.then((v2) => this.set(v2)).catch((err) => this.variable.emit("error", err))
            } else {
              this.set(v)
            }
          })
        } else if (this.pollExec) {
          this._poll = interval(this.pollInterval, () => {
            execAsync(this.pollExec)
              .then((v) => this.set(this.pollTransform(v, this.get())))
              .catch((err) => this.variable.emit("error", err))
          })
        }
      }
      startWatch() {
        if (this._watch) return
        this._watch = subprocess({ cmd: this.watchExec, out: (out) => this.set(this.watchTransform(out, this.get())), err: (err) => this.variable.emit("error", err) })
      }
      stopPoll() {
        this._poll?.cancel()
        delete this._poll
      }
      stopWatch() {
        this._watch?.kill()
        delete this._watch
      }
      isPolling() {
        return !!this._poll
      }
      isWatching() {
        return !!this._watch
      }
      drop() {
        this.variable.emit("dropped")
      }
      onDropped(callback) {
        this.variable.connect("dropped", callback)
        return this
      }
      onError(callback) {
        delete this.errHandler
        this.variable.connect("error", (_, err) => callback(err))
        return this
      }
      subscribe(callback) {
        const id = this.variable.connect("changed", () => {
          callback(this.get())
        })
        return () => this.variable.disconnect(id)
      }
      poll(interval2, exec2, transform = (out) => out) {
        this.stopPoll()
        this.pollInterval = interval2
        this.pollTransform = transform
        if (typeof exec2 === "function") {
          this.pollFn = exec2
          delete this.pollExec
        } else {
          this.pollExec = exec2
          delete this.pollFn
        }
        this.startPoll()
        return this
      }
      watch(exec2, transform = (out) => out) {
        this.stopWatch()
        this.watchExec = exec2
        this.watchTransform = transform
        this.startWatch()
        return this
      }
      observe(objs, sigOrFn, callback) {
        const f = typeof sigOrFn === "function" ? sigOrFn : (callback ?? (() => this.get()))
        const set = (obj, ...args) => this.set(f(obj, ...args))
        if (Array.isArray(objs)) {
          for (const obj of objs) {
            const [o, s] = obj
            const id = o.connect(s, set)
            this.onDropped(() => o.disconnect(id))
          }
        } else {
          if (typeof sigOrFn === "string") {
            const id = objs.connect(sigOrFn, set)
            this.onDropped(() => objs.disconnect(id))
          }
        }
        return this
      }
      static derive(deps, fn = (...args) => args) {
        const update = () => fn(...deps.map((d) => d.get()))
        const derived = new Variable(update())
        const unsubs = deps.map((dep) => dep.subscribe(() => derived.set(update())))
        derived.onDropped(() => unsubs.map((unsub) => unsub()))
        return derived
      }
    }
    Variable = new Proxy(VariableWrapper, { apply: (_t, _a, args) => new VariableWrapper(args[0]) })
    ;({ derive } = Variable)
    variable_default = Variable
  },
})
function mergeBindings(array) {
  function getValues(...args) {
    let i = 0
    return array.map((value) => (value instanceof binding_default ? args[i++] : value))
  }
  const bindings = array.filter((i) => i instanceof binding_default)
  if (bindings.length === 0) return array
  if (bindings.length === 1) return bindings[0].as(getValues)
  return variable_default.derive(bindings, getValues)()
}
function setProp(obj, prop, value) {
  try {
    const setter = `set_${snakeify2(prop)}`
    if (typeof obj[setter] === "function") return obj[setter](value)
    return (obj[prop] = value)
  } catch (error) {
    console.error(`could not set property "${prop}" on ${obj}:`, error)
  }
}
function hook(widget3, object, signalOrCallback, callback) {
  if (typeof object.connect === "function" && callback) {
    const id = object.connect(signalOrCallback, (_, ...args) => {
      callback(widget3, ...args)
    })
    widget3.connect("destroy", () => {
      object.disconnect(id)
    })
  } else if (typeof object.subscribe === "function" && typeof signalOrCallback === "function") {
    const unsub = object.subscribe((...args) => {
      signalOrCallback(widget3, ...args)
    })
    widget3.connect("destroy", unsub)
  }
}
function construct(widget3, config) {
  let { setup, child, children = [], ...props } = config
  if (children instanceof binding_default) {
    children = [children]
  }
  if (child) {
    children.unshift(child)
  }
  for (const [key, value] of Object.entries(props)) {
    if (value === void 0) {
      delete props[key]
    }
  }
  const bindings = Object.keys(props).reduce((acc, prop) => {
    if (props[prop] instanceof binding_default) {
      const binding = props[prop]
      delete props[prop]
      return [...acc, [prop, binding]]
    }
    return acc
  }, [])
  const onHandlers = Object.keys(props).reduce((acc, key) => {
    if (key.startsWith("on")) {
      const sig = kebabify(key).split("-").slice(1).join("-")
      const handler = props[key]
      delete props[key]
      return [...acc, [sig, handler]]
    }
    return acc
  }, [])
  const mergedChildren = mergeBindings(children.flat(Infinity))
  if (mergedChildren instanceof binding_default) {
    widget3[setChildren](mergedChildren.get())
    widget3.connect(
      "destroy",
      mergedChildren.subscribe((v) => {
        widget3[setChildren](v)
      })
    )
  } else {
    if (mergedChildren.length > 0) {
      widget3[setChildren](mergedChildren)
    }
  }
  for (const [signal2, callback] of onHandlers) {
    const sig = signal2.startsWith("notify") ? signal2.replace("-", "::") : signal2
    if (typeof callback === "function") {
      widget3.connect(sig, callback)
    } else {
      widget3.connect(sig, () => execAsync(callback).then(print).catch(console.error))
    }
  }
  for (const [prop, binding] of bindings) {
    if (prop === "child" || prop === "children") {
      widget3.connect(
        "destroy",
        binding.subscribe((v) => {
          widget3[setChildren](v)
        })
      )
    }
    widget3.connect(
      "destroy",
      binding.subscribe((v) => {
        setProp(widget3, prop, v)
      })
    )
    setProp(widget3, prop, binding.get())
  }
  for (const [key, value] of Object.entries(props)) {
    if (value === void 0) {
      delete props[key]
    }
  }
  Object.assign(widget3, props)
  setup?.(widget3)
  return widget3
}
function isArrowFunction(func) {
  return !Object.hasOwn(func, "prototype")
}
function jsx(ctors2, ctor, { children, ...props }) {
  children ??= []
  if (!Array.isArray(children)) children = [children]
  children = children.filter(Boolean)
  if (children.length === 1) props.child = children[0]
  else if (children.length > 1) props.children = children
  if (typeof ctor === "string") {
    if (isArrowFunction(ctors2[ctor])) return ctors2[ctor](props)
    return new ctors2[ctor](props)
  }
  if (isArrowFunction(ctor)) return ctor(props)
  return new ctor(props)
}
var noImplicitDestroy, setChildren
var init_astal = __esm({
  "../../../../nix/store/zqn3hxrlyyg9mkd267g0dvxa5rrcrd0c-astal-gjs/share/astal/gjs/_astal.ts"() {
    init_variable()
    init_process()
    init_binding()
    noImplicitDestroy = Symbol("no no implicit destroy")
    setChildren = Symbol("children setter method")
  },
})
import Astal5 from "gi://Astal?version=3.0"
import Gtk3 from "gi://Gtk?version=3.0"
import GObject2 from "gi://GObject"
function astalify(cls, clsName = cls.name) {
  class Widget5 extends cls {
    get css() {
      return Astal5.widget_get_css(this)
    }
    set css(css) {
      Astal5.widget_set_css(this, css)
    }
    get_css() {
      return this.css
    }
    set_css(css) {
      this.css = css
    }
    get className() {
      return Astal5.widget_get_class_names(this).join(" ")
    }
    set className(className) {
      Astal5.widget_set_class_names(this, className.split(/\s+/))
    }
    get_class_name() {
      return this.className
    }
    set_class_name(className) {
      this.className = className
    }
    get cursor() {
      return Astal5.widget_get_cursor(this)
    }
    set cursor(cursor) {
      Astal5.widget_set_cursor(this, cursor)
    }
    get_cursor() {
      return this.cursor
    }
    set_cursor(cursor) {
      this.cursor = cursor
    }
    get clickThrough() {
      return Astal5.widget_get_click_through(this)
    }
    set clickThrough(clickThrough) {
      Astal5.widget_set_click_through(this, clickThrough)
    }
    get_click_through() {
      return this.clickThrough
    }
    set_click_through(clickThrough) {
      this.clickThrough = clickThrough
    }
    get noImplicitDestroy() {
      return this[noImplicitDestroy]
    }
    set noImplicitDestroy(value) {
      this[noImplicitDestroy] = value
    }
    set actionGroup([prefix, group]) {
      this.insert_action_group(prefix, group)
    }
    set_action_group(actionGroup) {
      this.actionGroup = actionGroup
    }
    getChildren() {
      if (this instanceof Gtk3.Bin) {
        return this.get_child() ? [this.get_child()] : []
      } else if (this instanceof Gtk3.Container) {
        return this.get_children()
      }
      return []
    }
    setChildren(children) {
      children = children.flat(Infinity).map((ch) => (ch instanceof Gtk3.Widget ? ch : new Gtk3.Label({ visible: true, label: String(ch) })))
      if (this instanceof Gtk3.Container) {
        for (const ch of children) this.add(ch)
      } else {
        throw Error(`can not add children to ${this.constructor.name}`)
      }
    }
    [setChildren](children) {
      if (this instanceof Gtk3.Container) {
        for (const ch of this.getChildren()) {
          this.remove(ch)
          if (!children.includes(ch) && !this.noImplicitDestroy) ch?.destroy()
        }
      }
      this.setChildren(children)
    }
    toggleClassName(cn, cond = true) {
      Astal5.widget_toggle_class_name(this, cn, cond)
    }
    hook(object, signalOrCallback, callback) {
      hook(this, object, signalOrCallback, callback)
      return this
    }
    constructor(...params) {
      super()
      const props = params[0] || {}
      props.visible ??= true
      construct(this, props)
    }
  }
  GObject2.registerClass(
    {
      GTypeName: `Astal_${clsName}`,
      Properties: {
        "class-name": GObject2.ParamSpec.string("class-name", "", "", GObject2.ParamFlags.READWRITE, ""),
        css: GObject2.ParamSpec.string("css", "", "", GObject2.ParamFlags.READWRITE, ""),
        cursor: GObject2.ParamSpec.string("cursor", "", "", GObject2.ParamFlags.READWRITE, "default"),
        "click-through": GObject2.ParamSpec.boolean("click-through", "", "", GObject2.ParamFlags.READWRITE, false),
        "no-implicit-destroy": GObject2.ParamSpec.boolean("no-implicit-destroy", "", "", GObject2.ParamFlags.READWRITE, false),
      },
    },
    Widget5
  )
  return Widget5
}
var init_astalify = __esm({
  "../../../../nix/store/zqn3hxrlyyg9mkd267g0dvxa5rrcrd0c-astal-gjs/share/astal/gjs/gtk3/astalify.ts"() {
    init_astal()
  },
})
var widget_exports = {}
__export(widget_exports, {
  Box: () => Box,
  Button: () => Button,
  CenterBox: () => CenterBox,
  CircularProgress: () => CircularProgress,
  DrawingArea: () => DrawingArea,
  Entry: () => Entry,
  EventBox: () => EventBox,
  Icon: () => Icon,
  Label: () => Label,
  LevelBar: () => LevelBar,
  MenuButton: () => MenuButton,
  Overlay: () => Overlay,
  Revealer: () => Revealer,
  Scrollable: () => Scrollable,
  Slider: () => Slider,
  Stack: () => Stack,
  Switch: () => Switch,
  Window: () => Window,
})
import Astal6 from "gi://Astal?version=3.0"
import Gtk4 from "gi://Gtk?version=3.0"
import GObject3 from "gi://GObject"
function filter(children) {
  return children.flat(Infinity).map((ch) => (ch instanceof Gtk4.Widget ? ch : new Gtk4.Label({ visible: true, label: String(ch) })))
}
var Box, Button, CenterBox, CircularProgress, DrawingArea, Entry, EventBox, Icon, Label, LevelBar, MenuButton, Overlay, Revealer, Scrollable, Slider, Stack, Switch, Window
var init_widget = __esm({
  "../../../../nix/store/zqn3hxrlyyg9mkd267g0dvxa5rrcrd0c-astal-gjs/share/astal/gjs/gtk3/widget.ts"() {
    init_astalify()
    Object.defineProperty(Astal6.Box.prototype, "children", {
      get() {
        return this.get_children()
      },
      set(v) {
        this.set_children(v)
      },
    })
    Box = class extends astalify(Astal6.Box) {
      static {
        GObject3.registerClass({ GTypeName: "Box" }, this)
      }
      constructor(props, ...children) {
        super({ children: children, ...props })
      }
      setChildren(children) {
        this.set_children(filter(children))
      }
    }
    Button = class extends astalify(Astal6.Button) {
      static {
        GObject3.registerClass({ GTypeName: "Button" }, this)
      }
      constructor(props, child) {
        super({ child: child, ...props })
      }
    }
    CenterBox = class extends astalify(Astal6.CenterBox) {
      static {
        GObject3.registerClass({ GTypeName: "CenterBox" }, this)
      }
      constructor(props, ...children) {
        super({ children: children, ...props })
      }
      setChildren(children) {
        const ch = filter(children)
        this.startWidget = ch[0] || new Gtk4.Box()
        this.centerWidget = ch[1] || new Gtk4.Box()
        this.endWidget = ch[2] || new Gtk4.Box()
      }
    }
    CircularProgress = class extends astalify(Astal6.CircularProgress) {
      static {
        GObject3.registerClass({ GTypeName: "CircularProgress" }, this)
      }
      constructor(props, child) {
        super({ child: child, ...props })
      }
    }
    DrawingArea = class extends astalify(Gtk4.DrawingArea) {
      static {
        GObject3.registerClass({ GTypeName: "DrawingArea" }, this)
      }
      constructor(props) {
        super(props)
      }
    }
    Entry = class extends astalify(Gtk4.Entry) {
      static {
        GObject3.registerClass({ GTypeName: "Entry" }, this)
      }
      constructor(props) {
        super(props)
      }
    }
    EventBox = class extends astalify(Astal6.EventBox) {
      static {
        GObject3.registerClass({ GTypeName: "EventBox" }, this)
      }
      constructor(props, child) {
        super({ child: child, ...props })
      }
    }
    Icon = class extends astalify(Astal6.Icon) {
      static {
        GObject3.registerClass({ GTypeName: "Icon" }, this)
      }
      constructor(props) {
        super(props)
      }
    }
    Label = class extends astalify(Astal6.Label) {
      static {
        GObject3.registerClass({ GTypeName: "Label" }, this)
      }
      constructor(props) {
        super(props)
      }
      setChildren(children) {
        this.label = String(children)
      }
    }
    LevelBar = class extends astalify(Astal6.LevelBar) {
      static {
        GObject3.registerClass({ GTypeName: "LevelBar" }, this)
      }
      constructor(props) {
        super(props)
      }
    }
    MenuButton = class extends astalify(Gtk4.MenuButton) {
      static {
        GObject3.registerClass({ GTypeName: "MenuButton" }, this)
      }
      constructor(props, child) {
        super({ child: child, ...props })
      }
    }
    Object.defineProperty(Astal6.Overlay.prototype, "overlays", {
      get() {
        return this.get_overlays()
      },
      set(v) {
        this.set_overlays(v)
      },
    })
    Overlay = class extends astalify(Astal6.Overlay) {
      static {
        GObject3.registerClass({ GTypeName: "Overlay" }, this)
      }
      constructor(props, ...children) {
        super({ children: children, ...props })
      }
      setChildren(children) {
        const [child, ...overlays] = filter(children)
        this.set_child(child)
        this.set_overlays(overlays)
      }
    }
    Revealer = class extends astalify(Gtk4.Revealer) {
      static {
        GObject3.registerClass({ GTypeName: "Revealer" }, this)
      }
      constructor(props, child) {
        super({ child: child, ...props })
      }
    }
    Scrollable = class extends astalify(Astal6.Scrollable) {
      static {
        GObject3.registerClass({ GTypeName: "Scrollable" }, this)
      }
      constructor(props, child) {
        super({ child: child, ...props })
      }
    }
    Slider = class extends astalify(Astal6.Slider) {
      static {
        GObject3.registerClass({ GTypeName: "Slider" }, this)
      }
      constructor(props) {
        super(props)
      }
    }
    Stack = class extends astalify(Astal6.Stack) {
      static {
        GObject3.registerClass({ GTypeName: "Stack" }, this)
      }
      constructor(props, ...children) {
        super({ children: children, ...props })
      }
      setChildren(children) {
        this.set_children(filter(children))
      }
    }
    Switch = class extends astalify(Gtk4.Switch) {
      static {
        GObject3.registerClass({ GTypeName: "Switch" }, this)
      }
      constructor(props) {
        super(props)
      }
    }
    Window = class extends astalify(Astal6.Window) {
      static {
        GObject3.registerClass({ GTypeName: "Window" }, this)
      }
      constructor(props, child) {
        super({ child: child, ...props })
      }
    }
  },
})
import Astal7 from "gi://Astal?version=3.0"
import Gtk5 from "gi://Gtk?version=3.0"
import Gdk from "gi://Gdk?version=3.0"
var init_gtk3 = __esm({
  async "../../../../nix/store/zqn3hxrlyyg9mkd267g0dvxa5rrcrd0c-astal-gjs/share/astal/gjs/gtk3/index.ts"() {
    init_astalify()
    await init_app2()
    init_widget()
    init_astal()
  },
})
import Astal8 from "gi://AstalIO"
import Gio2 from "gi://Gio?version=2.0"
function readFile(path) {
  return Astal8.read_file(path) || ""
}
function readFileAsync(path) {
  return new Promise((resolve, reject) => {
    Astal8.read_file_async(path, (_, res) => {
      try {
        resolve(Astal8.read_file_finish(res) || "")
      } catch (error) {
        reject(error)
      }
    })
  })
}
function writeFile(path, content) {
  Astal8.write_file(path, content)
}
function writeFileAsync(path, content) {
  return new Promise((resolve, reject) => {
    Astal8.write_file_async(path, content, (_, res) => {
      try {
        resolve(Astal8.write_file_finish(res))
      } catch (error) {
        reject(error)
      }
    })
  })
}
function monitorFile(path, callback) {
  return Astal8.monitor_file(path, (file, event) => {
    callback(file, event)
  })
}
var init_file = __esm({ "../../../../nix/store/zqn3hxrlyyg9mkd267g0dvxa5rrcrd0c-astal-gjs/share/astal/gjs/file.ts"() {} })
import GLib2 from "gi://GLib?version=2.0"
import Gio3 from "gi://Gio?version=2.0"
async function sh(strings, ...values) {
  const cmd = typeof strings === "string" ? strings : strings.flatMap((str, i) => str + `${values[i] ?? ""}`).join("")
  return execAsync(["bash", "-c", cmd]).catch((err) => {
    console.error(cmd, err)
    return ""
  })
}
async function bash(strings, ...values) {
  const cmd = typeof strings === "string" ? strings : strings.flatMap((str, i) => str + `${values[i] ?? ""}`).join("")
  return execAsync(["bash", "-c", cmd])
}
function dependencies(...bins) {
  const missing = bins.filter((bin) => !GLib2.find_program_in_path(bin))
  if (missing.length > 0) {
    printerr(`missing dependencies: ${missing.join(", ")}`)
  }
  return missing.length === 0
}
function ls(path) {
  const list = []
  const dir = GLib2.Dir.open(path, 0)
  let file = dir.read_name()
  while (file) {
    if (!GLib2.file_test(`${path}/${file}`, GLib2.FileTest.IS_DIR)) {
      list.push(file)
    }
    file = dir.read_name()
  }
  return list
}
function mkdir(path) {
  if (!GLib2.file_test(path, GLib2.FileTest.IS_DIR)) {
    Gio3.File.new_for_path(path).make_directory_with_parents(null)
  }
  return path
}
var init_os = __esm({
  "lib/core/lib/os.ts"() {
    init_process()
  },
})
function throttle(ms, callback) {
  let last = 0
  return (...args) => {
    const now = new Date().getTime()
    if (now - last >= ms) {
      last = now
      callback(...args)
    }
  }
}
function debounce(ms, callback) {
  let time3
  return function (...args) {
    if (time3) time3.cancel()
    time3 = timeout(ms)
    return new Promise((res) => {
      time3.connect("now", () => res(callback(...args)))
      time3.connect("cancelled", () => res(null))
    })
  }
}
function sleep(ms) {
  return new Promise((res) => timeout(ms, () => res(null)))
}
var init_function = __esm({
  "lib/core/lib/function.ts"() {
    init_time()
  },
})
import GLib3 from "gi://GLib?version=2.0"
import Gio4 from "gi://Gio?version=2.0"
function getOptions(object, path = "") {
  return Object.keys(object).flatMap((key) => {
    const obj = object[key]
    const id = path ? path + "." + key : key
    if (obj instanceof Opt) {
      obj.id = id
      return obj
    }
    if (typeof obj === "object") return getOptions(obj, id)
    return []
  })
}
function opt(initial) {
  return new Opt(initial)
}
function parse(cacheFile) {
  try {
    return JSON.parse(readFile(cacheFile) || "{}")
  } catch (error) {
    printerr(error, cacheFile)
    return {}
  }
}
function mkOptions(name, object) {
  const options = getOptions(object)
  const cacheFile = `${CONFIG}/${name}.json`
  mkdir(CONFIG)
  if (!GLib3.file_test(cacheFile, GLib3.FileTest.EXISTS)) {
    writeFile(
      cacheFile,
      JSON.stringify(
        options.reduce((acc, opt2) => ({ ...acc, [opt2.id]: opt2.get() }), {}),
        null,
        4
      )
    )
  }
  for (const opt2 of options) opt2.init(cacheFile)
  monitorFile(cacheFile, (_, event) => {
    if (event === Gio4.FileMonitorEvent.CHANGED) {
      const config = parse(cacheFile)
      for (const opt2 of options) {
        if (config[opt2.id] !== void 0) {
          opt2.set(config[opt2.id])
        } else {
          opt2.reset()
        }
      }
    }
  })
  const opts = Object.assign(object, {
    options: () => options,
    reset: () => options.forEach((opt2) => opt2.reset()),
    set(id, value) {
      const config = parse(cacheFile)
      config[id] = value
      opts.get(id)?.set(value)
      writeFile(cacheFile, JSON.stringify(config, null, 2))
    },
    get(id) {
      if (id.startsWith(name)) id = id.replace(`${name}.`, "")
      return options.find((opt2) => opt2.id === id)
    },
    subscribe(callback) {
      const unsub = options.map((opt2) => opt2.subscribe(callback))
      return () => unsub.map((fn) => fn())
    },
  })
  return opts
}
var Opt
var init_option = __esm({
  "lib/core/lib/option.ts"() {
    init_variable()
    init_file()
    init_os()
    Opt = class extends variable_default {
      constructor(initial) {
        super(initial)
        this.initial = initial
      }
      initial
      id = ""
      toString = () => `${this.get()}`
      toJSON = () => this.get()
      get = () => super.get()
      set = (value) => {
        if (JSON.stringify(this.get()) !== JSON.stringify(value)) {
          super.set(value)
        }
      }
      init(cacheFile) {
        const cacheV = parse(cacheFile)[this.id]
        if (cacheV !== void 0) this.set(cacheV)
      }
      reset() {
        if (JSON.stringify(this.get()) !== JSON.stringify(this.initial)) {
          this.set(this.initial)
          return this.id
        }
      }
    }
  },
})
var options_default
var init_options = __esm({
  "lib/core/theme/options.ts"() {
    init_option()
    options_default = mkOptions("theme", {
      dark: { primary: opt("#51a4e7"), error: opt("#e55f86"), success: opt("#00D787"), bg: opt("#171717"), fg: opt("#eeeeee"), widget: opt("#eeeeee"), border: opt("#eeeeee") },
      light: { primary: opt("#426ede"), error: opt("#b13558"), success: opt("#009e49"), bg: opt("#fffffa"), fg: opt("#080808"), widget: opt("#080808"), border: opt("#080808") },
      blur: opt(1),
      scheme: opt("dark"),
      widget: { opacity: opt(94) },
      border: { width: opt(1), opacity: opt(96) },
      shadows: opt(true),
      padding: opt(9),
      spacing: opt(9),
      radius: opt(9),
      font: opt("Ubuntu Nerd Font 14"),
      hyprland: { enable: opt(false), inactiveBorder: { dark: opt("#282828"), light: opt("#181818") }, gapsMultiplier: opt(2.2) },
      swww: { enable: opt(false), args: opt("--transition-type fade") },
      tmux: { enable: opt(false), cmd: opt('tmux set @main_accent "{hex}"') },
      gsettings: { enable: opt(true) },
    })
  },
})
import Gio5 from "gi://Gio"
var gsettings_default
var init_gsettings = __esm({
  "lib/core/theme/integrations/gsettings.ts"() {
    init_options()
    gsettings_default = {
      async init() {
        try {
          const settings = new Gio5.Settings({ schema: "org.gnome.desktop.interface" })
          options_default.scheme.subscribe((scheme2) => {
            settings.set_string("color-scheme", `prefer-${scheme2}`)
          })
          settings.set_string("color-scheme", `prefer-${options_default.scheme.get()}`)
        } catch (error) {
          printerr("gsettings integration failed", error)
        }
      },
    }
  },
})
import Hyprland from "gi://AstalHyprland"
function rgba(color) {
  return `rgba(${color}ff)`.replace("#", "")
}
function sendBatch(...batch) {
  const hypr = Hyprland.get_default()
  const cmd = batch
    .filter((x) => !!x)
    .map((x) => `keyword ${x}`)
    .join("; ")
  return new Promise((resolve) => {
    hypr.message_async(`[[BATCH]]/${cmd}`, (_, res) => {
      resolve(hypr.message_finish(res))
    })
  })
}
async function reset() {
  if (!options_default.hyprland.enable.get()) return
  const { spacing: spacing2, border: border2, scheme: scheme2, dark: dark2, light: light2, radius: radius2, shadows: shadows2 } = options_default
  const { inactiveBorder, gapsMultiplier } = options_default.hyprland
  const wm_gaps = spacing2.get() * gapsMultiplier.get()
  const active = scheme2.get() === "dark" ? dark2.primary.get() : light2.primary.get()
  const inactive = scheme2.get() === "dark" ? inactiveBorder.dark.get() : inactiveBorder.light.get()
  sendBatch(
    `general:border_size ${border2.width.get()}`,
    `general:gaps_out ${wm_gaps}`,
    `general:gaps_in ${Math.floor(wm_gaps / 2)}`,
    `general:col.active_border ${rgba(active)}`,
    `general:col.inactive_border ${rgba(inactive)}`,
    `decoration:rounding ${radius2.get()}`,
    `decoration:shadow:enabled ${shadows2.get() ? "true" : "false"}`
  )
}
async function init2({ App, Astal: Astal10 }) {
  async function blur2(name) {
    await sendBatch(`layerrule unset, ${name}`)
    if (options_default.blur.get() > 0) {
      sendBatch(`layerrule unset, ${name}`, `layerrule blur, ${name}`, `layerrule ignorealpha ${0.39}, ${name}`)
    }
  }
  App.connect("window-added", (_, win) => {
    if (win instanceof Astal10.Window) blur2(win.namespace)
  })
  options_default.blur.subscribe(() => {
    for (const win of App.get_windows()) {
      if (win instanceof Astal10.Window) blur2(win.namespace)
    }
  })
}
var hyprland_default
var init_hyprland = __esm({
  "lib/core/theme/integrations/hyprland.ts"() {
    init_options()
    hyprland_default = { init: init2, reset: reset }
  },
})
import GLib4 from "gi://GLib?version=2.0"
function setWallpaper(wp) {
  return sh`cp ${wp} ${GLib4.get_user_config_dir()}/background`
}
async function wallpaper() {
  if (!enabled() || !dependencies("swww")) return
  const args = options_default.swww.args.get()
  return sh(`swww img ${args} ${WP}`)
}
var WP, enabled, swww_default
var init_swww = __esm({
  "lib/core/theme/integrations/swww.ts"() {
    init_process()
    init_file()
    init_os()
    init_function()
    init_options()
    WP = `${GLib4.get_user_config_dir()}/background`
    enabled = options_default.swww.enable.get
    swww_default = {
      async init() {
        if (!enabled() || !dependencies("swww-daemon")) return
        await execAsync("swww-daemon").catch(() => void 0)
        await wallpaper().then((v) => print(v))
        monitorFile(`${GLib4.get_user_config_dir()}/background`, debounce(5, wallpaper))
        options_default.swww.enable.subscribe((v) => {
          void (
            v &&
            execAsync("swww-daemon")
              .then(wallpaper)
              .catch(() => void 0)
          )
        })
      },
    }
  },
})
async function reset2() {
  if (!options_default.tmux.enable.get() || !dependencies("tmux")) return
  const { scheme: scheme2, dark: dark2, light: light2 } = options_default
  const hex = scheme2.get() === "dark" ? dark2.primary.get() : light2.primary.get()
  return sh(`tmux set @main_accent "${hex}"`)
}
var tmux_default
var init_tmux = __esm({
  "lib/core/theme/integrations/tmux.ts"() {
    init_os()
    init_options()
    tmux_default = { reset: reset2 }
  },
})
var integrations, integrations_default
var init_integrations = __esm({
  "lib/core/theme/integrations/index.ts"() {
    init_gsettings()
    init_hyprland()
    init_swww()
    init_tmux()
    integrations = [hyprland_default, swww_default, tmux_default, gsettings_default]
    integrations_default = integrations
  },
})
function tmpl(strings, ...values) {
  const deps = values.filter((v) => v instanceof variable_default || v instanceof binding_default)
  const indexes = deps.map((d) => values.indexOf(d))
  const evaluate = (...variableValues) => {
    let v = 0
    const val = (i) => (indexes.includes(i) ? variableValues[v++] : (values[i] ?? ""))
    return strings.flatMap((str, i) => str + `${String(val(i))}`).join("")
  }
  return variable_default.derive(deps, evaluate)
}
function lengthStr(length) {
  const min = Math.floor(length / 60)
  const sec = Math.floor(length % 60)
  const sec0 = sec < 10 ? "0" : ""
  return `${min}:${sec0}${sec}`
}
function cnames(...arg) {
  const names = arg.flatMap((item) => {
    if (item && typeof item === "string") {
      return item
    }
    if (typeof item === "object") {
      return Object.entries(item)
        .filter(([, v]) => v)
        .map(([name]) => name)
    }
    return null
  })
  return names.filter(Boolean).join(" ")
}
function fake(value) {
  return value instanceof binding_default ? value : binding_default.bind({ get: () => value, subscribe: () => () => void 0 })
}
var init_utils = __esm({
  "lib/core/lib/utils.ts"() {
    init_variable()
    init_binding()
  },
})
function t(dark2, light2) {
  if (typeof dark2 === "string" && typeof light2 === "string") return scheme((s) => (s === "dark" ? dark2 : light2))
  if (dark2 instanceof variable_default && light2 instanceof variable_default) {
    const v = variable_default.derive([scheme, dark2, light2], (s, d, l) => (s === "dark" ? d : l))
    return v()
  }
}
var dark, light, scheme, padding, spacing, radius, shadows, widget, border, blur, variables_default
var init_variables = __esm({
  "lib/core/theme/variables.ts"() {
    init_variable()
    init_utils()
    init_options()
    ;({ dark, light, scheme, padding, spacing, radius, shadows, widget, border, blur } = options_default)
    variables_default = tmpl`
@use 'sass:color';

$bg: transparentize(${t(dark.bg, light.bg)}, (${blur} * .01));
$fg: ${t(dark.fg, light.fg)};
$primary: ${t(dark.primary, light.primary)};
$error: ${t(dark.error, light.error)};
$success: ${t(dark.success, light.success)};
$accent-fg: ${t(dark.bg, light.bg)};

$padding: ${padding()}pt;
$spacing: ${spacing()}pt;
$radius: ${radius()}px;
$transition: 250ms;

$shadows: ${shadows()};

$widget-opacity: ${widget.opacity((v) => v * 0.01)};
$hover-opacity: ${widget.opacity((v) => v * 0.0097)};
$widget-bg: ${t(dark.widget, light.widget)};

$border-width: ${border.width()}px;
$border-color: transparentize(${t(dark.border, light.border)}, ${border.opacity((v) => v * 0.01)});
$border: $border-width solid $border-color;

$shadow-color: rgba(0,0,0,.6);
$text-shadow: 2px 2px 2px $shadow-color;
$box-shadow: 2px 2px 2px 0 $shadow-color, inset 0 0 0 $border-width $border-color;
`
  },
})
function scss(sheet) {
  const style = sheet.default || sheet
  stylesheets.set([...stylesheets.get(), style])
}
async function theme(props) {
  const { App } = props
  const reset3 = debounce(10, async () => {
    try {
      if (!dependencies("sass")) {
        App.quit()
      }
      const tmp = mkdir(`${TMP}/${App.instanceName}`)
      const scss2 = `${tmp}/main.scss`
      const css = `${tmp}/main.css`
      const sheet = variables_default.get() + stylesheets.get().join("\n")
      await writeFileAsync(scss2, sheet)
      await bash`sass ${scss2} ${css}`
      App.apply_css(css, true)
      for (const i of integrations_default) {
        if (i.reset) await i.reset(props)
      }
      return "reset"
    } catch (error) {
      logError(error)
      App.quit(1)
    }
  })
  for (const i of integrations_default) {
    if (i.init) await i.init(props)
  }
  options_default.subscribe(reset3)
  variables_default.subscribe(reset3)
  stylesheets.subscribe(reset3)
  return new Promise((res, rej) => {
    reset3()
      .then(() => idle(() => res(null)))
      .catch(rej)
  })
}
var stylesheets
var init_theme = __esm({
  "lib/core/theme/index.ts"() {
    init_variable()
    init_time()
    init_file()
    init_os()
    init_function()
    init_integrations()
    init_variables()
    init_options()
    stylesheets = variable_default([])
  },
})
import GObject4 from "gi://GObject"
import { default as default2 } from "gi://GLib?version=2.0"
function register(options = {}) {
  return function (cls) {
    const t2 = options.Template
    if (typeof t2 === "string" && !t2.startsWith("resource://") && !t2.startsWith("file://")) {
      options.Template = new TextEncoder().encode(t2)
    }
    GObject4.registerClass({ Signals: { ...cls[meta]?.Signals }, Properties: { ...cls[meta]?.Properties }, ...options }, cls)
    delete cls[meta]
  }
}
function property(declaration = Object) {
  return function (target, prop, desc) {
    target.constructor[meta] ??= {}
    target.constructor[meta].Properties ??= {}
    const name = kebabify2(prop)
    if (!desc) {
      Object.defineProperty(target, prop, {
        get() {
          return this[priv]?.[prop] ?? defaultValue(declaration)
        },
        set(v) {
          if (v !== this[prop]) {
            this[priv] ??= {}
            this[priv][prop] = v
            this.notify(name)
          }
        },
      })
      Object.defineProperty(target, `set_${name.replace("-", "_")}`, {
        value(v) {
          this[prop] = v
        },
      })
      Object.defineProperty(target, `get_${name.replace("-", "_")}`, {
        value() {
          return this[prop]
        },
      })
      target.constructor[meta].Properties[kebabify2(prop)] = pspec(name, ParamFlags.READWRITE, declaration)
    } else {
      let flags = 0
      if (desc.get) flags |= ParamFlags.READABLE
      if (desc.set) flags |= ParamFlags.WRITABLE
      target.constructor[meta].Properties[kebabify2(prop)] = pspec(name, flags, declaration)
    }
  }
}
function signal(declaration, ...params) {
  return function (target, signal2, desc) {
    target.constructor[meta] ??= {}
    target.constructor[meta].Signals ??= {}
    const name = kebabify2(signal2)
    if (declaration || params.length > 0) {
      const arr = [declaration, ...params].map((v) => v.$gtype)
      target.constructor[meta].Signals[name] = { param_types: arr }
    } else {
      target.constructor[meta].Signals[name] = declaration || { param_types: [] }
    }
    if (!desc) {
      Object.defineProperty(target, signal2, {
        value: function (...args) {
          this.emit(name, ...args)
        },
      })
    } else {
      const og = desc.value
      desc.value = function (...args) {
        this.emit(name, ...args)
      }
      Object.defineProperty(target, `on_${name.replace("-", "_")}`, {
        value: function (...args) {
          return og(...args)
        },
      })
    }
  }
}
function pspec(name, flags, declaration) {
  if (declaration instanceof ParamSpec) return declaration
  switch (declaration) {
    case String:
      return ParamSpec.string(name, "", "", flags, "")
    case Number:
      return ParamSpec.double(name, "", "", flags, -Number.MAX_VALUE, Number.MAX_VALUE, 0)
    case Boolean:
      return ParamSpec.boolean(name, "", "", flags, false)
    case Object:
      return ParamSpec.jsobject(name, "", "", flags)
    default:
      return ParamSpec.object(name, "", "", flags, declaration.$gtype)
  }
}
function defaultValue(declaration) {
  if (declaration instanceof ParamSpec) return declaration.get_default_value()
  switch (declaration) {
    case String:
      return ""
    case Number:
      return 0
    case Boolean:
      return false
    case Object:
    default:
      return null
  }
}
var meta, priv, ParamSpec, ParamFlags, kebabify2
var init_gobject = __esm({
  "../../../../nix/store/zqn3hxrlyyg9mkd267g0dvxa5rrcrd0c-astal-gjs/share/astal/gjs/gobject.ts"() {
    meta = Symbol("meta")
    priv = Symbol("priv")
    ;({ ParamSpec, ParamFlags } = GObject4)
    kebabify2 = (str) =>
      str
        .replace(/([a-z])([A-Z])/g, "$1-$2")
        .replaceAll("_", "-")
        .toLowerCase()
  },
})
import { default as default3 } from "gi://AstalIO?version=0.1"
var init_gjs = __esm({
  async "../../../../nix/store/zqn3hxrlyyg9mkd267g0dvxa5rrcrd0c-astal-gjs/share/astal/gjs/index.ts"() {
    await init_overrides()
    init_process()
    init_time()
    init_file()
    init_gobject()
    init_binding()
    init_variable()
  },
})
function jsx2(ctor, props) {
  return jsx(ctors, ctor, props)
}
var ctors, jsxs
var init_jsx_runtime = __esm({
  "../../../../nix/store/zqn3hxrlyyg9mkd267g0dvxa5rrcrd0c-astal-gjs/share/astal/gjs/gtk3/jsx-runtime.ts"() {
    init_astal()
    init_widget()
    ctors = {
      box: Box,
      button: Button,
      centerbox: CenterBox,
      circularprogress: CircularProgress,
      drawingarea: DrawingArea,
      entry: Entry,
      eventbox: EventBox,
      icon: Icon,
      label: Label,
      levelbar: LevelBar,
      menubutton: MenuButton,
      overlay: Overlay,
      revealer: Revealer,
      scrollable: Scrollable,
      slider: Slider,
      stack: Stack,
      switch: Switch,
      window: Window,
    }
    jsxs = jsx2
  },
})
function PopupBin({ child, p, r, className = "", ...props }) {
  const names = cnames("PopupBin", className, p && `p-${p}`, r && `r-${r}`)
  return jsx2("box", { className: names, ...props, children: child })
}
var init_PopupBin = __esm({
  "lib/gtk3/src/primitive/PopupBin.tsx"() {
    init_theme()
    init_utils()
    init_jsx_runtime()
    void scss`box.PopupBin { margin: 12px; border: $border-width solid color.mix($fg, $border-color, .4%); background-color: $bg; color: $fg; @include padding; &.r-sm { border-radius: $radius * 1.5; } &.r-md { border-radius: $radius * 1.8; } &.r-lg { border-radius: $radius * 2.1; } &.r-xl { border-radius: $radius * 2.4; } &.r-2xl { border-radius: $radius * 2.7; } &.r-3xl { border-radius: $radius * 3.0; } &.r-4xl { border-radius: $radius * 3.3; } @if $shadows { border: none; box-shadow: 2px 3px 6px 0 $shadow-color, inset 0 0 0 $border-width color.mix($fg, $border-color, .4%); }}`
  },
})
function PopupPadding({ h = false, v = false, width = 0, height = 0, child, onClick }) {
  const size2 = tmpl`
        min-width: ${fake(width)}rem;
        min-height: ${fake(height)}rem;
    `
  return jsx2("eventbox", { onDestroy: () => size2.drop(), onClick: onClick, hexpand: h, vexpand: v, children: jsx2("box", { css: size2(), children: child }) })
}
var init_PopupPadding = __esm({
  "lib/gtk3/src/primitive/PopupPadding.tsx"() {
    init_utils()
    init_jsx_runtime()
  },
})
var SearchEntry
var init_SearchEntry = __esm({
  async "lib/gtk3/src/primitive/SearchEntry.tsx"() {
    await init_gtk3()
    init_gobject()
    init_binding()
    init_theme()
    init_jsx_runtime()
    void scss`SearchEntry { color: transparentize($fg, .2); transition: $transition; button { all: unset; transition: $transition; color: transparentize($fg, .3); &:hover { color: transparentize($fg, .15); } &:focus { color: transparentize($primary, .15); } &:active { color: $primary; } } entry { all: unset; color: $fg; } icon.search { transition: $transition; font-size: .9em; margin-right: .4em; } label.placeholder { color: transparentize($fg, .4); } &.hover icon.search { color: transparentize($primary, .1); } &.focus icon.search { color: $primary; }}`
    SearchEntry = class extends widget_exports.Box {
      focus() {
        this._entry.grab_focus()
      }
      set_position(pos) {
        this._entry.set_position(pos)
      }
      constructor({ width = 10, ...props }) {
        super({ width: width, ...props })
        this.add(jsx2("icon", { visible: bind(this, "noIcon").as((v) => !v), className: "search", icon: "system-search-symbolic" }))
        this.add(
          jsxs("overlay", {
            children: [
              jsxs("box", {
                css: bind(this, "width").as((w) => `min-width: ${w}rem;`),
                children: [
                  jsx2("entry", {
                    hexpand: true,
                    setup: (self) => (this._entry = self),
                    widthChars: 0,
                    text: bind(this, "text"),
                    onChanged: (self) => this.onChanged(self.text),
                    onActivate: () => this.enter(),
                    onFocusInEvent: () => this.toggleClassName("focus", true),
                    onFocusOutEvent: () => this.toggleClassName("focus", false),
                    onEnterNotifyEvent: () => this.toggleClassName("hover", true),
                    onLeaveNotifyEvent: () => this.toggleClassName("hover", false),
                  }),
                  jsx2("revealer", {
                    transitionType: SLIDE_LEFT,
                    revealChild: bind(this, "text").as(Boolean),
                    children: jsx2("button", { onClicked: () => this.clear(), children: jsx2("icon", { icon: "edit-clear-symbolic" }) }),
                  }),
                ],
              }),
              jsx2("label", { className: "placeholder", visible: bind(this, "text").as((t2) => !t2), label: bind(this, "placeholder"), halign: START }),
            ],
          })
        )
      }
      onChanged(text) {
        this.text = text
        this.search()
      }
      clear() {
        this.text = ""
        this._entry.grab_focus()
      }
    }
    __decorateClass([property(String)], SearchEntry.prototype, "placeholder", 2)
    __decorateClass([property(String)], SearchEntry.prototype, "text", 2)
    __decorateClass([property(Number)], SearchEntry.prototype, "width", 2)
    __decorateClass([property(Boolean)], SearchEntry.prototype, "noIcon", 2)
    __decorateClass([signal()], SearchEntry.prototype, "enter", 2)
    __decorateClass([signal()], SearchEntry.prototype, "search", 2)
    SearchEntry = __decorateClass([register({ GTypeName: "SearchEntry", CssName: "SearchEntry" })], SearchEntry)
  },
})
function Search({ handler, text, position, child }) {
  return jsxs("box", {
    className: "Search",
    expand: false,
    children: [
      jsx2(SearchEntry, {
        onSearch: (self) => {
          text.set(self.text || "")
          handler({ text: self.text || "" })
        },
        onEnter: ({ text: text2 }) => {
          handler({ text: text2 || "", enter: true })
          app_default.get_window("launcher").visible = false
        },
        onKeyPressEvent: ({ text: text2 }, event) => {
          if (event.get_keyval()[1] === Gdk.KEY_Tab) {
            return handler({ text: text2 || "", complete: true })
          }
        },
        text: text(),
        placeholder: 'Type ":" to list subcommands',
        setup: (self) => {
          idle(() => self.focus())
          self.hook(position, () =>
            idle(() => {
              self.focus()
              self.set_position(position.get())
            })
          )
          self.hook(text, () => {
            if (self.text !== text.get()) self.focus()
          })
        },
      }),
      child,
    ],
  })
}
var init_Search = __esm({
  async "src/gtk3/src/launcher/Search.tsx"() {
    await init_gtk3()
    await init_SearchEntry()
    init_theme()
    init_time()
    init_jsx_runtime()
    void scss`.Search { padding: $padding; SearchEntry { padding: $padding / 2; }}`
  },
})
function Separator({ vertical = false, m, my, mx, mt, mb, mr, ml }) {
  const names = cnames("Separator", m && `m-${m}`, mx && `mx-${mx}`, my && `my-${my}`, mt && `mt-${mt}`, mb && `mb-${mb}`, ml && `ml-${ml}`, mr && `mr-${mr}`)
  return jsx2(GtkSeparator, { hexpand: !vertical, vexpand: vertical, className: names, orientation: vertical ? 1 : 0 })
}
var GtkSeparator
var init_Separator = __esm({
  async "lib/gtk3/src/primitive/Separator.tsx"() {
    await init_gjs()
    await init_gtk3()
    init_utils()
    init_theme()
    init_jsx_runtime()
    void scss`separator.Separator { @include margin; min-width: $border-width; min-height: $border-width; background-color: $border-color;}`
    GtkSeparator = class extends astalify(Gtk5.Separator) {
      static {
        GObject4.registerClass({ GTypeName: "Separator" }, this)
      }
      constructor(props) {
        super(props)
      }
    }
  },
})
function Box2({ child, children = [], gap, p, px, py, pt, pb, pl, pr, m, mx, my, mt, mb, ml, mr, r, className = "", vertical = false, widget: widget3 = false, ...props }) {
  const names = fake(className).as((className2) =>
    cnames(
      "Box",
      className2,
      vertical ? "vertical" : "horizontal",
      widget3 && "widget",
      gap ? `gap-${gap}` : "no-gap",
      p && `p-${p}`,
      px && `px-${px}`,
      py && `py-${py}`,
      pt && `pt-${pt}`,
      pb && `pb-${pb}`,
      pl && `pl-${pl}`,
      pr && `pr-${pr}`,
      m && `m-${m}`,
      mx && `mx-${mx}`,
      my && `my-${my}`,
      mt && `mt-${mt}`,
      mb && `mb-${mb}`,
      ml && `ml-${ml}`,
      mr && `mr-${mr}`,
      r && `r-${r}`
    )
  )
  return jsx2("box", { className: names, vertical: vertical, ...props, children: child || children })
}
var init_Box = __esm({
  "lib/gtk3/src/primitive/Box.tsx"() {
    init_theme()
    init_utils()
    init_jsx_runtime()
    void scss`box.Box { @include margin; @include padding; @include radius; &.raised { background-color: transparentize($widget-bg, $widget-opacity); box-shadow: inset 0 0 0 $border-width $border-color; } &.horizontal { &.gap-sm>* { margin: 0 ($spacing * .1); } &.gap-md>* { margin: 0 ($spacing * .2); } &.gap-lg>* { margin: 0 ($spacing * .3); } &.gap-xl>* { margin: 0 ($spacing * .4); } &.gap-2xl>* { margin: 0 ($spacing * .5); } &:not(.no-gap) { &>*:first-child { margin-left: 0; } &>*:last-child { margin-right: 0; } } } &.vertical { &.gap-sm>* { margin: ($spacing * .1) 0; } &.gap-md>* { margin: ($spacing * .2) 0; } &.gap-lg>* { margin: ($spacing * .3) 0; } &.gap-xl>* { margin: ($spacing * .4) 0; } &.gap-2xl>* { margin: ($spacing * .5) 0; } &:not(.no-gap) { &>*:first-child { margin-top: 0; } &>*:last-child { margin-bottom: 0; } } }}`
  },
})
function FlatButton({ child, color = "primary", className = "", ...props }) {
  const names = fake(color).as((c) => cnames("FlatButton", c, className))
  return jsx2("button", { className: names, ...props, children: child })
}
var init_FlatButton = __esm({
  "lib/gtk3/src/primitive/FlatButton.tsx"() {
    init_theme()
    init_utils()
    init_jsx_runtime()
    void scss`@mixin flat-button ($color) { icon { color: $color; &.flat { color: transparentize($color, .2) } } label { color: $fg; &.flat { color: transparentize($fg, .6) } } &:hover, &:focus { icon { color: $color; &.flat { color: transparentize($color, .1) } } label { color: $color; &.flat { color: transparentize($color, .3) } } } &:active { label, icon { color: $color; &.flat { color: $color; } } }}button.FlatButton { all: unset; @include flat-button($fg); &.primary { @include flat-button($primary) } &.error { @include flat-button($error) } &.success { @include flat-button($success) }}`
  },
})
function Help_default({ visible, onClicked, plugins: plugins2 }) {
  return jsx2("revealer", {
    revealChild: visible,
    transitionType: SLIDE_DOWN,
    children: jsx2(Box2, {
      vertical: true,
      pb: "xl",
      visible: plugins2((ps) => Object.keys(ps).length > 0),
      children: plugins2((plugins3) =>
        Object.entries(plugins3)
          .filter(([, p]) => p?.description)
          .map(([prefix, p]) =>
            jsxs("box", {
              vertical: true,
              children: [
                jsx2(Separator, {}),
                jsx2(FlatButton, {
                  onClicked: () => onClicked(prefix),
                  children: jsxs(Box2, {
                    hexpand: false,
                    px: "2xl",
                    m: "md",
                    children: [
                      jsx2("label", { label: `:${prefix}` }),
                      jsx2("box", { hexpand: true }),
                      jsx2("label", { css: "font-size: .8em", className: "flat", useMarkup: true, label: p.description }),
                    ],
                  }),
                }),
              ],
            })
          )
      ),
    }),
  })
}
var init_Help = __esm({
  async "src/gtk3/src/launcher/Help.tsx"() {
    await init_Separator()
    init_Box()
    init_FlatButton()
    init_jsx_runtime()
  },
})
import GLib6 from "gi://GLib"
var options_default2
var init_options2 = __esm({
  "src/gtk3/src/launcher/options.ts"() {
    init_option()
    options_default2 = mkOptions("launcher", {
      width: opt(0),
      separator: opt("padded"),
      margin: opt(70),
      default: { maxItems: opt(7), icon: { size: opt(4), monochrome: opt(false) } },
      dock: { enable: opt(true), action: opt("astal -t drawer"), icon: { size: opt(4), monochrome: opt(false) }, display: opt(["firefox", "wezterm", "nautilus", "calendar", "spotify"]) },
      hyprland: { enable: opt(false), prefix: opt("h"), icon: { size: opt(4), monochrome: opt(false) } },
      nix: { enable: opt(Boolean(GLib6.find_program_in_path("nix"))), prefix: opt("nx"), pkgs: opt("nixpkgs/nixos-unstable"), maxItems: opt(6) },
      sh: { enable: opt(true), prefix: opt("sh"), maxItems: opt(12) },
      music: { enable: opt(true), prefix: opt("m"), maxItems: opt(10), coverSize: opt(8), icon: { size: opt(1), monochrome: opt(false) } },
      powermenu: { enable: opt(true), prefix: opt("p"), shutdown: opt("shutdown now"), sleep: opt("systemctl suspend"), reboot: opt("systemctl reboot"), logout: opt("hyprctl dispatch exit") },
      bluetooth: { enable: opt(false), prefix: opt("bt") },
      notifications: { enable: opt(true), prefix: opt("n"), maxItems: opt(14) },
      calendar: { enable: opt(true), prefix: opt("cal"), app: opt("gnome-calendar") },
      wifi: { enable: opt(false), prefix: opt("nw"), maxItems: opt(10), settings: opt("gtk-launch gnome-control-center") },
      audio: { enable: opt(true), prefix: opt("a"), mixer: { names: opt(true) } },
      theme: {
        enable: opt(true),
        prefix: opt("th"),
        wallpapers: { directory: opt(`/home/${USER}/Pictures/Wallpapers`), height: opt(72), columns: opt(3) },
        accents: opt([
          { dark: "#e55f86", light: "#d15577" },
          { dark: "#00D787", light: "#43c383" },
          { dark: "#EBFF71", light: "#d8e77b" },
          { dark: "#51a4e7", light: "#4886c8" },
          { dark: "#9077e7", light: "#8861dd" },
          { dark: "#51e6e6", light: "#43c3c3" },
          { dark: "#ffffff", light: "#080808" },
        ]),
      },
    })
  },
})
function Button2({ child, flat: flat3 = false, m, mx, my, r = "lg", vfill = false, hfill = false, suggested: suggested2 = false, className = "", color = "regular", ...props }) {
  const names = variable_default.derive([fake(color), fake(suggested2), fake(className), fake(flat3)], (color2, suggested3, name, flat4) =>
    cnames("Button", name, color2, suggested3 && "suggested", m && `p-${m}`, mx && `px-${mx}`, my && `py-${my}`, r && `r-${r}`, flat4 && "flat")
  )
  return jsx2("button", { onDestroy: () => names.drop(), className: names(), ...props, children: jsx2("box", { halign: hfill ? FILL : CENTER, valign: vfill ? FILL : CENTER, children: child }) })
}
var init_Button = __esm({
  "lib/gtk3/src/primitive/Button.tsx"() {
    init_variable()
    init_theme()
    init_utils()
    init_jsx_runtime()
    void scss`@mixin button($bg-color, $fg-color, $hover-bg, $hover-fg, $active-bg, $active-fg) { @include padding($spacing); &.r-sm>box { border-radius: $radius * .3; } &.r-md>box { border-radius: $radius * .6; } &.r-lg>box { border-radius: $radius * .9; } &.r-xl>box { border-radius: $radius * 1.2; } &.r-2xl>box { border-radius: $radius * 1.5; } >box { transition: $transition; color: transparentize($fg-color, 0.1); } &.flat>box{ background-color: transparent; box-shadow: none; } &:not(.flat)>box { background-color: transparentize($bg-color, $widget-opacity); box-shadow: inset 0 0 0 $border-width $border-color; } &:focus>box { box-shadow: inset 0 0 0 $border-width $active-bg; background-color: transparentize($hover-bg, $hover-opacity); color: $hover-fg; } &:hover>box { box-shadow: inset 0 0 0 $border-width $border-color; background-color: transparentize($hover-bg, $hover-opacity); color: $hover-fg; } &.active, &:active, &:checked { >box { box-shadow: inset 0 0 0 $border-width $border-color; background-color: $active-bg; color: $accent-fg; } } &.active, &:checked { &:hover, &:focus { >box { box-shadow: inset 0 0 0 ($border-width*2) $accent-fg, inset 0 0 0 $border-width $primary; } } }}@mixin regular($bgc, $fgc) { @include button($fg, $fg, $bgc, $bgc, $bgc, $fgc)}@mixin suggest($bgc, $fgc) { @include button($bgc, $bgc, $bgc, $bgc, $bgc, $fgc)}button.Button { all: unset; &.regular:not(.suggested) { @include button($widget-bg, $fg, $widget-bg, $fg, $primary, $bg); } &.primary:not(.suggested) { @include regular($primary, $bg); } &.error:not(.suggested) { @include regular($error, $bg); } &.success:not(.suggested) { @include regular($success, $bg); } &.regular.suggested { @include button($widget-bg, $fg, $widget-bg, $fg, $primary, $bg); } &.primary.suggested { @include suggest($primary, $bg); } &.error.suggested { @include suggest($error, $bg); } &.success.suggested { @include suggest($success, $bg); }}`
  },
})
import GLib7 from "gi://GLib?version=2.0"
function initIcons(app) {
  if (GLib7.file_test(`${CONFIG}/icons`, GLib7.FileTest.EXISTS)) app.add_icons(`${CONFIG}/icons`)
}
function icon(name, fallback = "image-missing", checker) {
  if (!name) return fallback || ""
  const icon2 = substitutes[name] || name
  if (GLib7.file_test(icon2, GLib7.FileTest.EXISTS)) return icon2
  if (checker(icon2)) return icon2
  printerr(`no icon "${icon2}", fallback: "${fallback}"`)
  return fallback
}
function symbolic(i, s) {
  if (i == null) return symbolic("image-missing", s)
  return s ? (i.endsWith("-symbolic") ? i : i + "-symbolic") : i.endsWith("-symbolic") ? i.replace("-symbolic", "") : i
}
var substitutes
var init_icons = __esm({
  "lib/core/lib/icons.ts"() {
    init_file()
    substitutes = GLib7.file_test(`${CONFIG}/substitutes.json`, GLib7.FileTest.EXISTS) ? JSON.parse(readFile(`${CONFIG}/substitutes.json`)) : {}
  },
})
function Icon2({ fallback = "image-missing", size: size2 = 1, symbolic: symbolic2 = false, icon: icon2, css = "", ...props }) {
  const style = variable_default.derive([fake(css), fake(size2)], (css2, size3) => `font-size: ${size3}em; ${css2};`)
  const iconName = variable_default.derive([fake(icon2), fake(symbolic2), fake(fallback)], (i, s, f) => icon(symbolic(i || f, s), symbolic(f, s), (name) => !!Astal7.Icon.lookup_icon(name)))
  return jsx2("icon", {
    onDestroy: () => {
      style.drop()
      iconName.drop()
    },
    ...props,
    icon: iconName(),
    css: style(),
  })
}
var init_Icon = __esm({
  async "lib/gtk3/src/primitive/Icon.tsx"() {
    await init_gtk3()
    init_icons()
    init_variable()
    init_utils()
    init_icons()
    init_jsx_runtime()
    initIcons(app_default)
  },
})
function DockAppButton(app) {
  const { icon: icon2 } = options_default2.dock
  return jsx2(Button2, {
    flat: true,
    hfill: true,
    tooltipText: bind(app, "name"),
    onClicked: () => {
      app.launch()
      app_default.get_window("launcher").visible = false
    },
    children: jsx2(Box2, {
      p: "xl",
      children: jsx2(Icon2, { hexpand: true, symbolic: icon2.monochrome(), size: icon2.size(), halign: CENTER, icon: bind(app, "iconName"), fallback: "Application-x-executable" }),
    }),
  })
}
function Dock(apps) {
  return jsxs("box", {
    vertical: true,
    hexpand: false,
    className: "Dock",
    children: [jsx2(Separator, {}), jsx2(Box2, { gap: "lg", mt: "lg", p: "2xl", css: "padding-top: 0", children: apps((apps2) => apps2.map(DockAppButton)) })],
  })
}
var init_Dock = __esm({
  async "src/gtk3/src/launcher/plugins/dock/Dock.tsx"() {
    await init_gtk3()
    await init_Separator()
    init_Button()
    init_Box()
    await init_Icon()
    await init_gjs()
    init_options2()
    init_jsx_runtime()
  },
})
function DockIcon() {
  const { action } = options_default2.dock
  function click() {
    sh(action.get())
    app_default.get_window("launcher").visible = false
  }
  return jsx2(Button2, {
    vfill: true,
    flat: true,
    suggested: true,
    color: "primary",
    onClicked: click,
    children: jsx2(Box2, { px: "xl", children: jsx2(Icon2, { symbolic: true, icon: "view-grid" }) }),
  })
}
var init_DockIcon = __esm({
  async "src/gtk3/src/launcher/plugins/dock/DockIcon.tsx"() {
    init_options2()
    await init_gtk3()
    init_os()
    init_Box()
    init_Button()
    await init_Icon()
    init_jsx_runtime()
  },
})
import Apps from "gi://AstalApps"
function dock() {
  const list = Variable([])
  const apps = new Apps.Apps()
  function populate() {
    const show = display.get()
    list.set(typeof show === "number" ? apps.get_list().slice(0, show) : show.map((f) => apps.exact_query(f)[0]))
  }
  return { ui: Dock(list), icon: DockIcon(), search() {}, enter() {}, reload: populate }
}
var display
var init_dock = __esm({
  async "src/gtk3/src/launcher/plugins/dock/index.ts"() {
    await init_gjs()
    init_options2()
    await init_Dock()
    await init_DockIcon()
    ;({ display } = options_default2.dock)
  },
})
function AppButton({ app }) {
  const { icon: icon2 } = options_default2.default
  return jsx2(Button2, {
    hfill: true,
    flat: true,
    hexpand: true,
    className: "AppButton",
    onClicked: () => {
      app.launch()
      app_default.get_window("launcher").hide()
    },
    children: jsxs("box", {
      children: [
        jsx2(Box2, { p: "xl", children: jsx2(Icon2, { symbolic: icon2.monochrome(), size: icon2.size(), icon: app.iconName, fallback: "application-x-executable" }) }),
        jsxs(Box2, {
          pr: "lg",
          vertical: true,
          valign: CENTER,
          children: [
            jsx2("label", { className: "name", halign: START, label: app.name, truncate: true }),
            app.description && jsx2("label", { xalign: 0, className: "description", wrap: true, label: app.description }),
          ],
        }),
      ],
    }),
  })
}
var init_AppButton = __esm({
  async "src/gtk3/src/launcher/plugins/default/AppButton.tsx"() {
    await init_gtk3()
    init_Button()
    init_Box()
    await init_Icon()
    init_options2()
    init_theme()
    init_jsx_runtime()
    void scss`.Launcher .AppButton { label.name { font-weight: bold; } label.description { font-weight: normal; color: transparentize($fg, .2); font-size: .8em; }}`
  },
})
function ApplicationList({ list, visible }) {
  const nonempty = Variable.derive([list, visible], (l, v) => l.filter((app) => v.includes(app.entry)).length > 0)
  return jsx2("revealer", {
    transitionType: SLIDE_DOWN,
    revealChild: nonempty(),
    children: jsx2(Box2, {
      className: "ApplicationList",
      vertical: true,
      pb: "2xl",
      children: list.as((apps) =>
        apps.map((app) =>
          jsx2("revealer", {
            transitionType: SLIDE_DOWN,
            revealChild: visible.as((list2) => list2.includes(app.entry)),
            children: jsxs("box", { vertical: true, children: [jsx2(Separator, { my: "md" }), jsx2(Box2, { px: "2xl", children: jsx2(AppButton, { app: app }) })] }),
          })
        )
      ),
    }),
  })
}
var init_ApplicationList = __esm({
  async "src/gtk3/src/launcher/plugins/default/ApplicationList.tsx"() {
    await init_gjs()
    await init_AppButton()
    await init_Separator()
    init_Box()
    init_theme()
    init_jsx_runtime()
    void scss`.Launcher .ApplicationList { /* md Separator spacing */ margin-top: -$spacing * .4;}`
  },
})
import Apps2 from "gi://AstalApps"
function plug() {
  const apps = new Apps2.Apps({ minScore: 1 })
  const list = Variable([])
  const visible = Variable([])
  const q = (s) => apps.exact_query(s)
  const populate = () => list.set(q(""))
  return {
    ui: ApplicationList({ list: list(), visible: visible() }),
    reload: populate,
    search(search) {
      visible.set(
        q(search)
          .slice(0, maxItems.get())
          .map((app) => app.entry)
      )
    },
    enter(entered) {
      q(entered)[0]?.launch()
    },
  }
}
var maxItems
var init_default = __esm({
  async "src/gtk3/src/launcher/plugins/default/index.ts"() {
    await init_gjs()
    init_options2()
    await init_ApplicationList()
    ;({ maxItems } = options_default2.default)
  },
})
function Spinner({ icon: icon2 = "process-working", spin = true, className = "" }) {
  return jsx2(Icon2, { symbolic: true, icon: icon2, className: fake(spin).as((spin2) => cnames("Spinner", className, { spin: spin2 })) })
}
var init_Spinner = __esm({
  async "lib/gtk3/src/primitive/Spinner.tsx"() {
    init_utils()
    init_theme()
    await init_Icon()
    init_jsx_runtime()
    void scss`Spinner.spin { @keyframes spin { to { -gtk-icon-transform: rotate(1turn); } } & { animation-name: spin; animation-duration: 1s; animation-timing-function: linear; animation-iteration-count: infinite; }}`
  },
})
function NixPkgButton({ pname, version, description }) {
  const { pkgs: pkgs2 } = options_default2.nix
  return jsx2(FlatButton, {
    hexpand: true,
    onClicked: () => {
      app_default.get_window("launcher").visible = false
      execAsync(`nix run ${pkgs2.get()}#${pname}`).catch(console.error)
    },
    children: jsxs(Box2, {
      vertical: true,
      m: "md",
      px: "2xl",
      children: [
        jsxs("box", { hexpand: false, children: [jsx2("label", { label: pname }), jsx2("box", { hexpand: true }), jsx2("label", { label: version })] }),
        jsx2("label", { wrap: true, className: "flat", halign: START, xalign: 0, label: description }),
      ],
    }),
  })
}
function Nix_default({ pkgs: pkgs2, loading }) {
  return jsx2("revealer", {
    transitionType: SLIDE_DOWN,
    revealChild: pkgs2.as((pkgs3) => pkgs3.length > 0),
    children: jsx2(Box2, {
      visible: loading.as((l) => !l),
      vertical: true,
      pb: "xl",
      children: pkgs2.as((pkgs3) => pkgs3.map((pkg) => jsxs("box", { vertical: true, children: [jsx2(Separator, {}), jsx2(NixPkgButton, { ...pkg })] }))),
    }),
  })
}
var init_Nix = __esm({
  async "src/gtk3/src/launcher/plugins/nix/Nix.tsx"() {
    await init_gtk3()
    await init_gjs()
    await init_Separator()
    init_Box()
    init_FlatButton()
    init_options2()
    init_jsx_runtime()
  },
})
function nix() {
  for (const dep of ["nix", "fzf", "head"]) {
    if (!dependencies(dep)) {
      throw Error(`missing dependency: ${dep}`)
    }
  }
  mkdir(CACHE)
  const list = `${CACHE}/nixpkgs`
  const nixpkgs = Variable({})
  const filter2 = Variable([])
  const found = Variable.derive([nixpkgs, filter2], (nixpkgs2, filter3) =>
    filter3
      .map((f) => {
        if (!nixpkgs2[`${PREFIX}${f}`]) return null
        return nixpkgs2[`${PREFIX}${f}`]
      })
      .filter((pkg) => pkg)
  )
  execAsync(`nix search ${pkgs} ^ --json`).then((json) => {
    const obj = JSON.parse(json)
    const content = Object.keys(obj)
      .map((n) => n.replace(PREFIX, ""))
      .join("\n")
    writeFileAsync(list, content).then(() => {
      nixpkgs.set(obj)
    })
  })
  return {
    description: pkgs((pkgs2) => `Run a nix package from ${pkgs2}`),
    icon: Spinner({ icon: "nix", spin: nixpkgs((pkgs2) => Object.values(pkgs2).length === 0) }),
    ui: Nix_default({ loading: nixpkgs((pkgs2) => Object.values(pkgs2).length === 0), pkgs: found() }),
    search(search) {
      bash`cat ${list} | fzf -f "${search}" | head -n ${maxItems2.get()}`.then((out) => filter2.set(out.split("\n"))).catch(console.error)
    },
    complete(search) {
      const res = exec(["bash", "-c", `cat ${list} | fzf -f "${search}" | head -n 1`])
      return res === search ? "" : res
    },
    enter(entered) {
      const [pkg, ...args] = entered.split(/\s+/)
      execAsync(`nix run ${pkgs}#${pkg} -- ${args.join(" ")}`).catch(console.error)
    },
  }
}
var pkgs, maxItems2, PREFIX
var init_nix = __esm({
  async "src/gtk3/src/launcher/plugins/nix/index.ts"() {
    await init_gjs()
    init_os()
    await init_Spinner()
    init_options2()
    await init_Nix()
    ;({ pkgs, maxItems: maxItems2 } = options_default2.nix)
    PREFIX = "legacyPackages.x86_64-linux."
  },
})
import Hyprland2 from "gi://AstalHyprland"
function Client({ client }) {
  const { icon: icon2 } = options_default2.hyprland
  return jsxs("box", {
    className: "Client",
    children: [
      jsx2(Button2, {
        hfill: true,
        vfill: true,
        flat: true,
        hexpand: true,
        onClicked: () => {
          client.focus()
          app_default.get_window("launcher").hide()
        },
        children: jsxs("box", {
          children: [
            jsx2(Box2, { p: "lg", children: jsx2(Icon2, { symbolic: icon2.monochrome(), icon: client.class, size: icon2.size(), fallback: "application-x-executable" }) }),
            jsx2("label", { xalign: 0, wrap: true, label: bind(client, "title") }),
          ],
        }),
      }),
      jsx2(Button2, {
        hfill: true,
        flat: true,
        suggested: true,
        color: "error",
        onClicked: () => {
          client.kill()
          app_default.get_window("launcher").hide()
        },
        children: jsx2(Box2, { p: "lg", children: jsx2(Icon2, { symbolic: true, icon: "window-close" }) }),
      }),
    ],
  })
}
function HyprlandClients_default(filter2) {
  const clients = bind(Hyprland2.get_default(), "clients")
  return jsxs(Box2, {
    vertical: true,
    className: "Hyprland",
    pb: "2xl",
    children: [
      jsxs(Box2, {
        vertical: true,
        className: "ZeroApps",
        visible: clients.as((cs) => cs.length === 0),
        children: [
          jsx2(Separator, {}),
          jsxs(Box2, { pt: "2xl", halign: CENTER, children: [jsx2(Icon2, { symbolic: true, css: "margin-right: .1em", icon: "application-x-executable" }), "There are no applications running."] }),
        ],
      }),
      jsx2(Box2, {
        className: "List",
        vertical: true,
        children: clients.as((cs) =>
          cs.map((c) =>
            jsx2("revealer", {
              transitionType: SLIDE_DOWN,
              revealChild: filter2((filter3) => filter3.includes(c.title)),
              children: jsxs("box", { vertical: true, children: [jsx2(Separator, { my: "md" }), jsx2(Box2, { px: "2xl", children: jsx2(Client, { client: c }) })] }),
            })
          )
        ),
      }),
    ],
  })
}
var init_HyprlandClients = __esm({
  async "src/gtk3/src/launcher/plugins/hyprland/HyprlandClients.tsx"() {
    await init_gtk3()
    init_Box()
    init_Button()
    await init_Icon()
    await init_Separator()
    await init_gjs()
    init_theme()
    init_options2()
    init_jsx_runtime()
    void scss`.Launcher .Hyprland { .ZeroApps icon { color: $error; } .List { /* md Separator spacing */ margin-top: -$spacing * .4; }}`
  },
})
import Hyprland3 from "gi://AstalHyprland"
function hyprland() {
  if (!dependencies("fzf")) throw Error("missing dependency: fzf")
  const hyprland2 = Hyprland3.get_default()
  if (!hyprland2) {
    console.error("could not connect to Hyprland")
    app_default.quit()
  }
  const filter2 = Variable([])
  const titles = () =>
    hyprland2
      .get_clients()
      .sort((a, b) => a.workspace.id - b.workspace.id)
      .map((c) => c.title)
      .join("\n")
  function setFilter(arr) {
    if (JSON.stringify(arr) !== JSON.stringify(filter2.get())) filter2.set(arr)
  }
  return {
    description: "Hyprland running clients",
    ui: HyprlandClients_default(filter2),
    icon: "window-close",
    search(search) {
      bash`echo "${titles()}" | fzf -f "${search}"`.then((out) => setFilter(out == "" ? [] : out.split("\n"))).catch(() => setFilter([]))
    },
    enter({ search }) {
      bash`echo "${titles()}" | fzf -f "${search}" | head -n 1`
        .then((title) => {
          hyprland2
            .get_clients()
            .find((c) => c.title == title)
            ?.focus()
          app_default.get_window("launcher").visible = false
        })
        .catch(() => {})
    },
  }
}
var init_hyprland2 = __esm({
  async "src/gtk3/src/launcher/plugins/hyprland/index.ts"() {
    await init_gtk3()
    await init_gjs()
    init_os()
    await init_HyprlandClients()
  },
})
function Sh(bins) {
  return jsx2("revealer", {
    revealChild: bins((b) => b.length > 0),
    transitionType: SLIDE_DOWN,
    children: jsx2(Box2, {
      vertical: true,
      className: "Sh",
      pb: "2xl",
      children: bins((bins2) =>
        bins2.map((bin) =>
          jsxs("box", {
            vertical: true,
            children: [
              jsx2(Separator, {}),
              jsx2(FlatButton, {
                onClicked: () => {
                  execAsync(bin).catch(console.error)
                  app_default.get_window("launcher").visible = false
                },
                children: jsx2(Box2, { m: "md", px: "2xl", children: jsx2("label", { wrap: true, xalign: 0, label: bin }) }),
              }),
            ],
          })
        )
      ),
    }),
  })
}
var init_Sh = __esm({
  async "src/gtk3/src/launcher/plugins/sh/Sh.tsx"() {
    await init_gtk3()
    init_process()
    await init_Separator()
    init_Box()
    init_FlatButton()
    init_jsx_runtime()
  },
})
function sh2() {
  const { maxItems: maxItems3 } = options_default2.sh
  if (!dependencies("fzf")) {
    throw Error("missing dependency: fzf")
  }
  mkdir(CACHE)
  const binaries = `${CACHE}/binaries`
  Promise.all(
    default2
      .getenv("PATH")
      .split(":")
      .map((path) => execAsync(`ls ${path}`).catch(() => ""))
  ).then((exe) => writeFileAsync(binaries, exe.join("\n")))
  const bins = Variable([])
  return {
    description: "Run executables from PATH",
    icon: { icon: "utilities-terminal", color: "success" },
    ui: Sh(bins),
    search(search) {
      if (!search) bins.set(binaries.split("\n").slice(maxItems3.get()))
      bash`cat ${binaries} | fzf -f "${search}" | head -n ${maxItems3.get()}`
        .then((str) => {
          bins.set(Array.from(new Set(str.split("\n")).values()).filter(Boolean))
        })
        .catch(() => bins.set([]))
    },
    enter(entered) {
      bash(entered).catch(console.error)
    },
    complete(search) {
      const res = exec(["bash", "-c", `cat ${binaries} | fzf -f "${search}" | head -n 1`])
      return res === search ? "" : res
    },
  }
}
var init_sh = __esm({
  async "src/gtk3/src/launcher/plugins/sh/index.ts"() {
    await init_gjs()
    init_file()
    init_process()
    init_os()
    await init_Sh()
    init_options2()
  },
})
function Slider2({ color = "primary", className = "", size: size2 = "lg", slider = false, squared = false, ...props }) {
  const names = cnames("Slider", className, color, size2, slider && "slider", squared && "squared")
  return new widget_exports.Slider({ className: names, expand: true, drawValue: false, ...props })
}
var init_Slider = __esm({
  async "lib/gtk3/src/primitive/Slider.tsx"() {
    await init_gtk3()
    init_theme()
    init_utils()
    void scss`@mixin slider($size, $color) { &:not(.squared) { trough { border-radius: $radius; highlight, progress { border-radius: max($radius - $border-width, 0); } } } &:not(.slider) { slider { opacity: 0; } } slider { margin: ($size * -.7); } trough { transition: $transition; border: $border; background-color: transparentize($fg, $widget-opacity); min-height: $size; min-width: $size; highlight, progress { background-color: $color; min-height: $size; min-width: $size; } } &:hover trough { background-color: transparentize($color, $hover-opacity); } &:disabled { highlight, progress { background-color: transparentize($fg, 0.4); } } trough:focus { background-color: transparentize($color, $hover-opacity); box-shadow: inset 0 0 0 $border-width $primary; } &.slider { slider { background-color: $fg; border: $border; transition: $transition; border-radius: $radius; min-height: $size; min-width: $size; } &:hover slider { background-color: $fg; border-color: $border-color; } @if $shadows { slider { box-shadow: 1px 1px 3px 0 $shadow-color; } &:hover slider { box-shadow: 0 0 5px 0 $shadow-color; } } }}.Slider { all: unset; * { all: unset; } &.regular.sm { @include slider(.4rem, $fg) } &.regular.md { @include slider(.6rem, $fg) } &.regular.lg { @include slider(.8rem, $fg) } &.primary.sm { @include slider(.4rem, $primary) } &.primary.md { @include slider(.6rem, $primary) } &.primary.lg { @include slider(.8rem, $primary) }}`
  },
})
import Mpris from "gi://AstalMpris"
function MediaPlayer({ player, maxChars: maxChars2 = 30, coverSize = 8 }) {
  const { icon: icon2 } = options_default2.music
  const coverArt = Variable.derive(
    [fake(coverSize), bind(player, "coverArt")],
    (s, url) => `
            min-width: ${s}rem;
            min-height: ${s}rem;
            background-image: url('${url}');
        `
  )
  const cover = jsx2(Box2, {
    hexpand: false,
    r: "lg",
    valign: START,
    className: "cover-art",
    css: coverArt(),
    children: jsx2(Icon2, {
      symbolic: true,
      hexpand: true,
      css: fake(coverSize).as((s) => `font-size: ${s * 0.7}rem`),
      halign: CENTER,
      icon: "audio-x-generic",
      visible: bind(player, "coverArt").as((c) => !c),
    }),
  })
  const title = jsx2("label", { hexpand: true, xalign: 0, halign: START, className: "title", maxWidthChars: maxChars2, truncate: true, label: bind(player, "title").as((t2) => t2 || "") })
  const artist = jsx2("label", { hexpand: true, xalign: 0, halign: START, className: "artist", maxWidthChars: maxChars2, truncate: true, label: bind(player, "artist").as((a) => a || "") })
  const positionSlider = jsx2(Slider2, {
    size: "sm",
    color: "regular",
    valign: CENTER,
    vexpand: false,
    visible: bind(player, "length").as((l) => l > 0),
    onDragged: throttle(100, ({ value }) => (player.position = value * player.length)),
    value: bind(player, "position").as((p) => (player.length > 0 ? p / player.length : 0)),
  })
  const positionLabel = jsx2("label", { className: "position", hexpand: true, halign: START, visible: bind(player, "length").as((l) => l > 0), label: bind(player, "position").as(lengthStr) })
  const lengthLabel = jsx2("label", {
    className: "length",
    hexpand: true,
    halign: END,
    visible: bind(player, "length").as((l) => l > 0),
    label: bind(player, "length").as((l) => (l > 0 ? lengthStr(l) : "0:00")),
  })
  const playerIcon = jsx2(Icon2, { symbolic: icon2.monochrome(), size: icon2.size(), icon: bind(player, "entry"), fallback: "audio-x-generic", tooltipText: bind(player, "identity") })
  const playPause = jsx2(Button2, {
    flat: true,
    mx: "sm",
    className: "play-pause",
    visible: bind(player, "canPlay"),
    onClicked: () => player.play_pause(),
    children: jsx2(Box2, {
      p: "md",
      children: jsx2(Icon2, {
        icon: bind(player, "playbackStatus").as((s) => {
          switch (s) {
            case Mpris.PlaybackStatus.PLAYING:
              return "media-playback-pause"
            default:
              return "media-playback-start"
          }
        }),
      }),
    }),
  })
  const prev = jsx2(Button2, {
    flat: true,
    mx: "sm",
    onClicked: () => player.previous(),
    visible: bind(player, "canGoPrevious"),
    children: jsx2(Box2, { p: "md", children: jsx2(Icon2, { symbolic: true, icon: "media-skip-backward" }) }),
  })
  const next = jsx2(Button2, {
    flat: true,
    mx: "sm",
    onClicked: () => player.next(),
    visible: bind(player, "canGoNext"),
    children: jsx2(Box2, { p: "md", children: jsx2(Icon2, { symbolic: true, icon: "media-skip-forward" }) }),
  })
  return jsxs(Box2, {
    vexpand: false,
    className: "MediaPlayer",
    r: "2xl",
    children: [
      cover,
      jsxs(Box2, {
        py: "sm",
        px: "2xl",
        vertical: true,
        css: "padding-right: 0",
        children: [
          jsxs("box", { children: [title, playerIcon] }),
          artist,
          jsxs("box", {
            valign: END,
            vexpand: true,
            vertical: true,
            children: [jsx2(Box2, { py: "md", children: positionSlider }), jsxs("centerbox", { children: [positionLabel, jsxs("box", { children: [prev, playPause, next] }), lengthLabel] })],
          }),
        ],
      }),
    ],
  })
}
var init_MediaPlayer = __esm({
  async "src/gtk3/src/launcher/plugins/media/MediaPlayer.tsx"() {
    await init_gjs()
    init_Box()
    init_Button()
    await init_Icon()
    await init_Slider()
    init_function()
    init_utils()
    init_theme()
    init_options2()
    init_jsx_runtime()
    void scss`.MediaPlayer { .cover-art { background-size: cover; background-position: center; @if $shadows { box-shadow: $box-shadow; } } label.title { color: $fg; font-weight: bold; } label.description { color: transparentize($fg, .2); }}`
  },
})
import Mpris2 from "gi://AstalMpris"
function Media(filter2) {
  const players = bind(Mpris2.get_default(), "players")
  const { coverSize } = options_default2.music
  return jsxs(Box2, {
    vertical: true,
    className: "Media",
    pb: "2xl",
    children: [
      jsxs(Box2, {
        vertical: true,
        className: "NonPlaying",
        visible: players.as((ps) => ps.length === 0),
        children: [
          jsx2(Separator, {}),
          jsxs(Box2, { pt: "2xl", halign: CENTER, children: [jsx2(Icon2, { symbolic: true, css: "margin-right: .1em", icon: "emblem-music" }), "There is no media playing."] }),
        ],
      }),
      jsx2(Box2, {
        vertical: true,
        className: "List",
        children: players.as((ps) =>
          ps.map((p) =>
            jsx2("revealer", {
              transitionType: SLIDE_DOWN,
              revealChild: filter2((f) => {
                const filter3 = f.toLowerCase()
                const entry = p.entry?.toLowerCase() ?? ""
                const id = p.identity?.toLowerCase() ?? ""
                return entry.includes(filter3) || id.includes(filter3)
              }),
              children: jsxs("box", { vertical: true, children: [jsx2(Separator, { my: "md" }), jsx2(Box2, { px: "2xl", children: jsx2(MediaPlayer, { coverSize: coverSize(), player: p }) })] }),
            })
          )
        ),
      }),
    ],
  })
}
var init_Media = __esm({
  async "src/gtk3/src/launcher/plugins/media/Media.tsx"() {
    await init_gjs()
    await init_MediaPlayer()
    await init_Separator()
    init_Box()
    init_theme()
    init_options2()
    await init_Icon()
    init_jsx_runtime()
    void scss`.Launcher .Media { .NonPlaying icon { color: $error; } .List { /* md Separator spacing */ margin-top: -$spacing * .4; }}`
  },
})
import Mpris3 from "gi://AstalMpris"
function media() {
  const mpris = Mpris3.get_default()
  const filter2 = Variable("")
  return {
    icon: "emblem-music",
    description: "Control media players",
    ui: Media(filter2),
    search(search) {
      filter2.set(search)
    },
    enter(entered) {
      const player = mpris.get_players().find((p) => {
        const filter3 = entered.toLowerCase()
        const entry = p.entry?.toLowerCase() ?? ""
        const id = p.identity?.toLowerCase() ?? ""
        return entry.includes(filter3) || id.includes(filter3)
      })
      if (player) player.play_pause()
    },
  }
}
var init_media = __esm({
  async "src/gtk3/src/launcher/plugins/media/index.ts"() {
    await init_gjs()
    await init_Media()
  },
})
function PowerButton({ btn, label }) {
  const clicked = () => exec(options_default2.powermenu[btn].get())
  const icons2 = { sleep: "weather-clear-night", reboot: "system-reboot", logout: "system-log-out", shutdown: "system-shutdown" }
  return jsx2(FlatButton, {
    color: "error",
    onClicked: clicked,
    children: jsxs(Box2, { hexpand: true, px: "2xl", m: "lg", children: [jsx2(Icon2, { symbolic: true, css: "margin-right: .3em", icon: icons2[btn] }), jsx2("label", { label: label })] }),
  })
}
function PowerMenu(filter2) {
  const btns = [
    ["shutdown", "Shutdown"],
    ["logout", "Log Out"],
    ["reboot", "Reboot"],
    ["sleep", "Sleep"],
  ]
  return jsx2(Box2, {
    vertical: true,
    pb: "xl",
    children: btns.map(([btn, label]) =>
      jsx2("revealer", {
        transitionType: SLIDE_DOWN,
        revealChild: filter2((f) => f.includes(btn)),
        children: jsxs("box", { vertical: true, children: [jsx2(Separator, {}), jsx2(PowerButton, { btn: btn, label: label })] }),
      })
    ),
  })
}
var init_PowerMenu = __esm({
  async "src/gtk3/src/launcher/plugins/powermenu/PowerMenu.tsx"() {
    await init_Separator()
    init_FlatButton()
    init_Box()
    await init_Icon()
    init_options2()
    init_process()
    init_jsx_runtime()
  },
})
function Uptime() {
  const uptime = Variable(0).poll(6e4, "cat /proc/uptime", (line) => Number.parseInt(line.split(".")[0]) / 60)
  const className = uptime((up) => {
    if (up > 4 * 60) return "error"
    return "primary"
  })
  return jsxs("box", {
    className: "Uptime",
    tooltipText: "Uptime",
    children: [jsx2("label", { label: uptime(lengthStr), css: "margin-right: .2em" }), jsx2(Icon2, { symbolic: true, className: className, icon: "hourglass" })],
  })
}
var init_Uptime = __esm({
  async "src/gtk3/src/launcher/plugins/powermenu/Uptime.tsx"() {
    await init_gjs()
    await init_Icon()
    init_utils()
    init_jsx_runtime()
  },
})
function powermenu() {
  if (!dependencies("fzf")) {
    throw Error("missing dependency: fzf")
  }
  const { powermenu: powermenu3 } = options_default2
  const buttons = ["shutdown", "logout", "reboot", "sleep"]
  const filter2 = Variable(buttons)
  return {
    description: "Shutdown and go sleepy time",
    icon: Uptime(),
    ui: PowerMenu(filter2),
    search(search) {
      bash`echo "${buttons.join("\n")}" | fzf -f "${search}"`.then((out) => out && filter2.set(out.split("\n"))).catch(() => {})
    },
    enter(entered) {
      bash`echo "${buttons.join("\n")}" | fzf -f "${entered}" | head -n 1`.then((out) => out && exec(powermenu3[out]?.get())).catch(() => {})
    },
  }
}
var init_powermenu = __esm({
  async "src/gtk3/src/launcher/plugins/powermenu/index.ts"() {
    await init_gjs()
    init_os()
    await init_PowerMenu()
    await init_Uptime()
    init_options2()
  },
})
import Notifd from "gi://AstalNotifd"
function Notification({ notification }) {
  const n = notification
  const showBody = Variable(false)
  const className = cnames("Notification", notification.urgency === Notifd.Urgency.CRITICAL && "critical")
  return jsxs(Box2, {
    vertical: true,
    className: className,
    children: [
      jsxs(Box2, {
        className: "header",
        gap: "sm",
        p: "md",
        pl: "lg",
        children: [
          (n.appIcon || n.desktopEntry) && jsx2(Icon2, { symbolic: true, className: "icon", css: "font-size: 1rem", icon: n.appIcon || n.desktopEntry }),
          jsx2("label", { className: "name", halign: START, truncate: true, label: n.appName }),
          jsx2("label", { className: "time", hexpand: true, halign: END, label: time(n.time) }),
          jsx2("box", { children: jsx2(Button2, { onClicked: () => showBody.set(!showBody.get()), children: jsx2(Box2, { m: "sm", children: jsx2(Icon2, { symbolic: true, icon: "pan-down" }) }) }) }),
          jsx2("box", {
            children: jsx2(Button2, {
              onClicked: () => n.dismiss(),
              color: "error",
              flat: true,
              suggested: true,
              children: jsx2(Box2, { m: "sm", children: jsx2(Icon2, { symbolic: true, icon: "window-close" }) }),
            }),
          }),
        ],
      }),
      jsx2("revealer", {
        revealChild: showBody(),
        transitionType: SLIDE_DOWN,
        children: jsxs("box", {
          vertical: true,
          children: [
            jsxs(Box2, {
              gap: "xl",
              p: "lg",
              className: "body",
              children: [
                n.image && default2.file_test(n.image, default2.FileTest.EXISTS) && jsx2("box", { valign: START, className: "image", css: `background-image: url('${n.image}')` }),
                n.image &&
                  Astal7.Icon.lookup_icon(n.image) &&
                  jsx2("box", { expand: false, valign: START, className: "icon-image", children: jsx2("icon", { icon: n.image, expand: true, halign: CENTER, valign: CENTER }) }),
                jsxs(Box2, {
                  vertical: true,
                  children: [
                    jsx2("label", { className: "title", halign: START, xalign: 0, label: n.summary, truncate: true }),
                    n.body && jsx2("label", { wrap: true, useMarkup: true, halign: START, xalign: 0, justifyFill: true, label: n.body }),
                  ],
                }),
              ],
            }),
            n.get_actions().length > 0 &&
              jsx2(Box2, {
                gap: "xl",
                m: "md",
                children: n.get_actions().map(({ label, id }) =>
                  jsx2(Button2, {
                    suggested: true,
                    color: "primary",
                    hexpand: true,
                    hfill: true,
                    onClicked: () => n.invoke(id),
                    children: jsx2(Box2, { my: "md", children: jsx2("label", { label: label, halign: CENTER, hexpand: true }) }),
                  })
                ),
              }),
          ],
        }),
      }),
    ],
  })
}
var time
var init_Notification = __esm({
  async "src/gtk3/src/launcher/plugins/notifications/Notification.tsx"() {
    await init_gtk3()
    await init_gjs()
    init_Box()
    init_Button()
    await init_Icon()
    init_utils()
    init_theme()
    init_jsx_runtime()
    void scss`.Launcher box.Notification { color: $fg; box.header { .icon { color: $primary } .name { color: transparentize($fg, .1) } .time { color: transparentize($fg, .4) } } box.body { box.image, box.icon-image { min-height: 5rem; min-width: 5rem; } box.image { border-radius: $radius; background-size: cover; background-position: center; @if $shadows { box-shadow: $box-shadow; } } box.icon-image icon { font-size: 4.8em; @if $shadows { -gtk-icon-shadow: $text-shadow; } } .title { font-weight: bold; font-size: 1.14rem; } } .critical .body .title { color: $error; }}`
    time = (time3, format2 = "%H:%M") => default2.DateTime.new_from_unix_local(time3).format(format2)
  },
})
import Notifd2 from "gi://AstalNotifd"
function Notifs(filter2) {
  const notifd = Notifd2.get_default()
  const notifs = Variable.derive([bind(notifd, "notifications"), options_default2.notifications.maxItems], (ns, max) => ns.slice(0, max).sort((a, b) => a.time - b.time))
  return jsxs(Box2, {
    vertical: true,
    className: "Notifications",
    pb: "2xl",
    children: [
      jsx2(Box2, {
        vertical: true,
        className: "List",
        children: notifs((ns) =>
          ns.map((n) =>
            jsx2("revealer", {
              revealChild: filter2((f) => f.length === 0 || f.includes(n.appName.toLowerCase())),
              transitionType: SLIDE_DOWN,
              children: jsxs("box", { vertical: true, children: [jsx2(Separator, { my: "md" }), jsx2(Box2, { px: "2xl", children: jsx2(Notification, { notification: n }) })] }),
            })
          )
        ),
      }),
      jsxs("box", {
        vertical: true,
        visible: bind(notifd, "notifications").as((ns) => ns.length == 0),
        children: [
          jsx2(Separator, {}),
          jsxs(Box2, {
            pt: "2xl",
            halign: CENTER,
            children: [jsx2(Icon2, { symbolic: true, icon: "notifications-disabled-symbolic", css: "margin-right: .1em", className: "error" }), "There are no messages yet"],
          }),
        ],
      }),
    ],
  })
}
var init_Notifications = __esm({
  async "src/gtk3/src/launcher/plugins/notifications/Notifications.tsx"() {
    await init_gjs()
    await init_Separator()
    init_Box()
    await init_Notification()
    await init_Icon()
    init_options2()
    init_theme()
    init_jsx_runtime()
    void scss`.Launcher .Notifications { .List { /* md Separator spacing */ margin-top: -$spacing * .4; }}`
  },
})
function ToggleButton({ state = false, onToggled, setup, ...props }) {
  const innerState = Variable(state instanceof Binding ? state.get() : state)
  return Button2({
    ...props,
    setup(self) {
      setup?.(self)
      self.toggleClassName("active", innerState.get())
      self.hook(innerState, () => self.toggleClassName("active", innerState.get()))
      if (state instanceof Binding) {
        self.hook(state, () => innerState.set(state.get()))
      }
    },
    onClicked(self) {
      onToggled?.(self, !innerState.get())
    },
  })
}
var init_ToggleButton = __esm({
  async "lib/gtk3/src/primitive/ToggleButton.tsx"() {
    await init_gjs()
    init_Button()
  },
})
import Notifd3 from "gi://AstalNotifd"
function DND() {
  const notifd = Notifd3.get_default()
  return jsx2(ToggleButton, {
    suggested: true,
    color: "primary",
    vfill: true,
    mx: "md",
    state: bind(notifd, "dontDisturb"),
    onToggled: () => (notifd.dontDisturb = !notifd.dontDisturb),
    children: jsx2(Box2, {
      px: "xl",
      vexpand: true,
      children: jsx2(Icon2, { symbolic: true, icon: bind(notifd, "dontDisturb").as((dnd) => (dnd ? "notifications-disabled-symbolic" : "org.gnome.Settings-notifications-symbolic")) }),
    }),
  })
}
function ClearButton() {
  const notifd = Notifd3.get_default()
  const notifs = bind(notifd, "notifications").as((ns) => ns.length)
  const icon2 = notifs.as((l) => (l > 0 ? "user-trash-full" : "user-trash"))
  async function clear() {
    while (notifd.get_notifications().length > 0) {
      notifd.get_notifications()[0]?.dismiss()
      await sleep(100)
    }
    app_default.get_window("launcher").visible = false
  }
  return jsx2("revealer", {
    revealChild: notifs.as((l) => l > 0),
    transitionType: SLIDE_LEFT,
    children: jsx2(Button2, {
      mx: "md",
      vfill: true,
      hfill: true,
      sensitive: notifs.as((l) => l > 0),
      tooltipText: "Clear",
      flat: true,
      suggested: true,
      color: "error",
      onClicked: clear,
      children: jsxs(Box2, { px: "xl", children: [jsx2(Icon2, { symbolic: true, icon: icon2, css: "margin-right:.2em" }), "Clear"] }),
    }),
  })
}
function NotifButton() {
  return jsxs("box", { children: [jsx2(DND, {}), jsx2(ClearButton, {})] })
}
var init_NotifButton = __esm({
  async "src/gtk3/src/launcher/plugins/notifications/NotifButton.tsx"() {
    await init_gtk3()
    await init_gjs()
    init_function()
    init_Button()
    init_Box()
    await init_ToggleButton()
    await init_Icon()
    init_jsx_runtime()
  },
})
import Notifd4 from "gi://AstalNotifd"
function notifications() {
  if (!dependencies("fzf")) {
    throw Error("missing dependency: fzf")
  }
  const filter2 = Variable([])
  const apps = () =>
    Notifd4.get_default()
      .get_notifications()
      .map((n) => n.appName.toLowerCase())
      .join("\n")
  return {
    description: `List of notifications`,
    icon: NotifButton(),
    ui: Notifs(filter2),
    search(search) {
      bash`echo "${apps()}" | fzf -f "${search}"`.then((out) => out && filter2.set(out.split("\n"))).catch(() => {})
    },
    enter() {},
  }
}
var init_notifications = __esm({
  async "src/gtk3/src/launcher/plugins/notifications/index.ts"() {
    await init_gjs()
    await init_Notifications()
    await init_NotifButton()
    init_os()
  },
})
function range(start2, end) {
  if (typeof end === "number") return Array.from({ length: end - start2 + 1 }, (_, i) => i + start2)
  return Array.from({ length: start2 }, (_, i) => i)
}
function chunks(size2, arr) {
  const result = []
  for (let i = 0; i < arr.length; i += size2) {
    const chunk = arr.slice(i, i + size2)
    result.push(chunk)
  }
  return result
}
var init_array = __esm({ "lib/core/lib/array.ts"() {} })
function isLeapYear(year) {
  return (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0
}
function matrix(y, m) {
  const firstDay = (new Date(y, m - 1, 1).getDay() + 6) % 7
  const thisMonth = range(1, (isLeapYear(y) ? leap : days).at(m - 1)).map((i) => ({ i: i, current: true }))
  const lastMonth = range(1, (isLeapYear(y) ? leap : days).at(m - 2)).map((i) => ({ i: i, prev: true }))
  const mx = [...lastMonth.slice(firstDay === 0 ? -7 : -firstDay), ...thisMonth]
  const nextMonth = range(1, 6 * 7 - mx.length).map((i) => ({ i: i, next: true }))
  return chunks(7, mx.concat(nextMonth))
}
function Calendar({ date, mark }) {
  function onClick(d) {
    let { month, year } = date.get()
    if (d.next) {
      if (month == 12) {
        month = 0
        year += 1
      } else {
        month += 1
      }
    }
    if (d.prev) {
      if (month == 0) {
        month = 12
        year -= 1
      } else {
        month -= 1
      }
    }
    date.set({ day: d.i, month: month, year: year })
  }
  function className({ prev, next, i }) {
    return date(({ day }) => cnames({ prev: prev, next: next }, !prev && !next && i === day && "active"))
  }
  return jsxs(Box2, {
    vertical: true,
    className: "Calendar",
    children: [
      jsx2(Box2, { className: "day-names", pb: "sm", homogeneous: true, children: abbr }),
      jsx2(Box2, {
        gap: "lg",
        className: "days",
        vertical: true,
        children: date(({ year, month }) =>
          matrix(year, month).map((row) =>
            jsx2(Box2, {
              gap: "lg",
              homogeneous: true,
              children: row.map((day) =>
                jsx2(Button2, {
                  hfill: true,
                  flat: true,
                  color: "primary",
                  className: className(day),
                  onClicked: () => onClick(day),
                  children: jsx2(Box2, {
                    halign: CENTER,
                    hexpand: true,
                    children: jsxs("overlay", {
                      children: [jsx2(Box2, { p: "lg", children: day.i }), jsx2("box", { visible: (mark && mark(year, month, day.i)) ?? false, className: "dot", valign: END, halign: CENTER })],
                    }),
                  }),
                })
              ),
            })
          )
        ),
      }),
    ],
  })
}
var days, leap, abbr
var init_Calendar = __esm({
  async "src/gtk3/src/launcher/plugins/calendar/Calendar.tsx"() {
    await init_gjs()
    init_theme()
    init_array()
    init_utils()
    init_Box()
    init_Button()
    init_jsx_runtime()
    void scss`.Calendar { box.day-names { color: $primary; } button.prev, button.next { label { transition: $transition; color: transparentize($fg, .8); } &:focus, &:hover { label { color: transparentize($fg, .6); } } } button.Button { box.dot { min-height: .2em; min-width: .2em; border-radius: $radius; border: $border; transition: $transition; background-color: $fg; } &:active, &.active { box.dot { background-color: $bg; } } &:hover box.dot { background-color: $primary; } &.prev, &.next { box.dot { background-color: transparentize($fg, .8); } &:focus, &:hover { box.dot { background-color: transparentize($fg, .6); } } } }}`
    days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    leap = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    abbr = [1, 2, 3, 4, 5, 6, 7].map((d) => default2.DateTime.new_utc(2001, 1, d, 0, 0, 0).format("%a"))
  },
})
function Cal(caldate) {
  return jsxs(Box2, { vertical: true, children: [jsx2(Separator, {}), jsx2(Box2, { p: "xl", children: jsx2(Calendar, { date: caldate }) })] })
}
var init_CalendarUI = __esm({
  async "src/gtk3/src/launcher/plugins/calendar/CalendarUI.tsx"() {
    init_Box()
    await init_Separator()
    await init_Calendar()
    init_jsx_runtime()
  },
})
function CalendarIcon(date) {
  function tooltip() {
    const { year, month, day } = date.get()
    return default2.DateTime.new_utc(year, month, day, 0, 0, 0).format("%Y. %m. %d.")
  }
  function onClick() {
    bash(options_default2.calendar.app.get()).catch(printerr)
    app_default.get_window("launcher").visible = false
  }
  return jsx2(Button2, {
    flat: true,
    suggested: true,
    color: "primary",
    tooltipText: tooltip(),
    onClicked: onClick,
    children: jsx2(Box2, { py: "md", px: "xl", children: jsx2(Icon2, { symbolic: true, icon: "x-office-calendar" }) }),
  })
}
var init_CalendarIcon = __esm({
  async "src/gtk3/src/launcher/plugins/calendar/CalendarIcon.tsx"() {
    await init_gtk3()
    await init_gjs()
    init_Button()
    init_Box()
    init_options2()
    init_os()
    await init_Icon()
    init_jsx_runtime()
  },
})
function calendar() {
  const [year, month, day] = default2.DateTime.new_now_local().get_ymd()
  const date = Variable({ day: day, month: month, year: year })
  return {
    icon: CalendarIcon(date),
    ui: Cal(date),
    description: "Calendar and events",
    reload() {
      const [year2, month2, day2] = default2.DateTime.new_now_local().get_ymd()
      date.set({ year: year2, month: month2, day: day2 })
    },
    search(search) {
      print(search)
    },
    enter(entered) {
      print(entered)
    },
  }
}
var init_calendar = __esm({
  async "src/gtk3/src/launcher/plugins/calendar/index.ts"() {
    await init_gjs()
    await init_CalendarUI()
    await init_CalendarIcon()
  },
})
import Network from "gi://AstalNetwork"
import NM from "gi://NM"
function AccessPoint({ ap }) {
  const nw = Network.get_default()
  const selected = bind(nw.wifi, "activeAccessPoint").as((aap) => aap == ap)
  const color = bind(ap, "strength").as((s) => {
    if (s > 75) return "success"
    if (s > 50) return "primary"
    return "error"
  })
  const bitrate = bind(ap, "maxBitrate").as((br) => `${br / 1e3} Mbit/s`)
  const hasPW = bind(ap, "wpaFlags").as((flags) => flags !== noPw)
  const lock = Variable.derive([hasPW, selected], (pw, s) => pw && !s)
  function connect() {
    print("todo", ap.ssid)
  }
  return jsx2(FlatButton, {
    color: color,
    onClicked: connect,
    children: jsxs(Box2, {
      px: "2xl",
      m: "md",
      children: [
        jsx2(Icon2, { symbolic: true, css: "margin-right:.2em", icon: bind(ap, "iconName") }),
        jsx2(Icon2, { symbolic: true, visible: lock(), icon: "system-lock-screen", css: "margin-right:.2em;color:white" }),
        jsx2(Icon2, { symbolic: true, visible: selected, icon: "object-select", css: selected.as((s) => `opacity: ${s ? 100 : 0}`) }),
        jsx2("label", { css: "margin-left:.2em", label: bind(ap, "ssid").as(String), wrap: true }),
        jsx2("label", { hexpand: true, halign: END, className: "flat", label: bitrate }),
      ],
    }),
  })
}
function Wifi(filter2) {
  const nw = Network.get_default()
  const aps = Variable.derive([bind(nw.wifi, "accessPoints"), bind(nw.wifi, "strength")], (aps2) => aps2.sort((a, b) => b.strength - a.strength))
  return jsx2("revealer", {
    revealChild: aps((aps2) => aps2.length > 0),
    transitionType: SLIDE_DOWN,
    children: jsx2(Box2, {
      vertical: true,
      pb: "xl",
      className: "Network",
      children: aps((aps2) => aps2.map((ap) => jsxs(Box2, { vertical: true, visible: filter2((f) => f.includes(ap.ssid)), children: [jsx2(Separator, { my: "md" }), jsx2(AccessPoint, { ap: ap })] }))),
    }),
  })
}
var noPw
var init_Wifi = __esm({
  async "src/gtk3/src/launcher/plugins/wifi/Wifi.tsx"() {
    init_Box()
    init_FlatButton()
    await init_Separator()
    await init_Icon()
    await init_gjs()
    init_theme()
    init_jsx_runtime()
    noPw = NM["80211ApSecurityFlags"].NONE
    void scss`.Launcher .Network { /* md Separator spacing */ margin-top: -$spacing * .4;}`
  },
})
import Network2 from "gi://AstalNetwork"
function WifiIcon() {
  const { wifi } = Network2.get_default()
  const { settings } = options_default2.wifi
  const color = bind(wifi, "strength").as((s) => {
    if (s > 75) return "success"
    if (s > 50) return "primary"
    return "error"
  })
  return jsx2(Button2, {
    vfill: true,
    flat: true,
    suggested: true,
    color: color,
    tooltipText: bind(wifi, "ssid"),
    onClicked: () => sh(settings.get()),
    children: jsx2(Box2, { px: "xl", children: jsx2("icon", { icon: bind(wifi, "iconName") }) }),
  })
}
var init_WifiIcon = __esm({
  async "src/gtk3/src/launcher/plugins/wifi/WifiIcon.tsx"() {
    await init_gjs()
    init_Box()
    init_Button()
    init_options2()
    init_os()
    init_jsx_runtime()
  },
})
import Network3 from "gi://AstalNetwork"
function sh3() {
  if (!dependencies("fzf")) {
    throw Error("missing dependency: fzf")
  }
  const { maxItems: maxItems3 } = options_default2.wifi
  const nw = Network3.get_default()
  const ssids = () => nw.wifi.get_access_points().map((ap) => ap.ssid)
  const networks = Variable(ssids())
  nw.wifi.scan()
  return {
    description: "List of available wifi networks",
    icon: WifiIcon(),
    ui: Wifi(networks),
    search(search) {
      if (!search) networks.set(ssids().slice(maxItems3.get()))
      bash`echo "${ssids().join("\n")}" | fzf -f "${search}" | head -n ${maxItems3.get()}`
        .then((str) => networks.set(str.split("\n")))
        .catch((err) => {
          print(err)
          networks.set([])
        })
    },
    enter() {
      print(networks.get()[0])
    },
  }
}
var init_wifi = __esm({
  async "src/gtk3/src/launcher/plugins/wifi/index.ts"() {
    await init_gjs()
    init_os()
    init_options2()
    await init_Wifi()
    await init_WifiIcon()
  },
})
function DarkMode() {
  function toggle() {
    const s = options_default.scheme.get()
    options_default.set("scheme", s === "dark" ? "light" : "dark")
  }
  return jsx2(ToggleButton, {
    state: options_default.scheme((s) => s === "dark"),
    onToggled: toggle,
    color: "primary",
    vfill: true,
    hfill: true,
    mx: "md",
    suggested: true,
    children: jsx2(Box2, { py: "md", px: "xl", children: jsx2(Icon2, { symbolic: true, icon: options_default.scheme((s) => `${s}-mode`) }) }),
  })
}
var init_DarkMode = __esm({
  async "src/gtk3/src/launcher/plugins/theme/DarkMode.tsx"() {
    init_Box()
    await init_Icon()
    await init_ToggleButton()
    init_options()
    init_jsx_runtime()
  },
})
import GdkPixbuf from "gi://GdkPixbuf"
import GLib8 from "gi://GLib?version=2.0"
import Gio6 from "gi://Gio?version=2.0"
function thumbnail(file, size2 = 256) {
  return new Promise((resolve, reject) => {
    const result = `${CACHE}/thumbnail/${GLib8.path_get_basename(file)}`
    if (GLib8.file_test(result, GLib8.FileTest.EXISTS)) return resolve(result)
    mkdir(`${CACHE}/thumbnail`)
    const f = Gio6.File.new_for_path(file)
    f.read_async(GLib8.PRIORITY_DEFAULT, null, (_, res) => {
      try {
        const stream = f.read_finish(res)
        GdkPixbuf.Pixbuf.new_from_stream_async(stream, null, (_2, f2) => {
          try {
            const pb = GdkPixbuf.Pixbuf.new_from_stream_finish(f2)
            const ratio = pb.width / pb.height
            let scaledHeight
            let scaledWidth
            if (ratio > 1) {
              scaledWidth = size2
              scaledHeight = size2 / ratio
            } else {
              scaledHeight = size2
              scaledWidth = size2 * ratio
            }
            pb.scale_simple(scaledWidth, scaledHeight, GdkPixbuf.InterpType.BILINEAR)?.savev(result, "jpeg", [], [])
            resolve(result)
          } catch (error) {
            reject(error)
          }
        })
      } catch (error) {
        reject(error)
      }
    })
  })
}
var init_utils2 = __esm({
  "lib/gtk3/src/utils.ts"() {
    init_os()
  },
})
function AccentPicker() {
  function set({ dark: dark2, light: light2 }) {
    options_default.set("dark.primary", dark2)
    options_default.set("light.primary", light2)
  }
  const current = Variable.derive([options_default.dark.primary, options_default.light.primary], (dark2, light2) => ({ dark: dark2, light: light2 }))
  return jsx2(Box2, {
    gap: "2xl",
    halign: CENTER,
    children: options_default2.theme.accents((as) =>
      as.map((accent) =>
        jsx2("button", {
          className: current((current2) => cnames("AccentColor", current2.dark === accent.dark && current2.light === accent.light && "active")),
          tooltipText: options_default.scheme((s) => accent[s]),
          css: options_default.scheme((s) => `color: ${accent[s]}`),
          onClicked: () => set(accent),
        })
      )
    ),
  })
}
var init_AccentPicker = __esm({
  async "src/gtk3/src/launcher/plugins/theme/AccentPicker.tsx"() {
    init_Box()
    init_options2()
    init_options()
    init_theme()
    init_utils()
    await init_gjs()
    init_jsx_runtime()
    void scss`button.AccentColor { all: unset; transition: $transition; border-radius: $radius; background-color: currentColor; min-height: 1.5rem; min-width: 1.8rem; border: $border; margin: $spacing; outline-color: transparent; outline-style: solid; outline-width: $border-width; outline-offset: $border-width; -gtk-outline-radius: $radius + ($border-width * 2); &:focus, &:hover, &:active { outline-color: currentColor; } &.active { box-shadow: inset 0 0 0 $border-width $accent-fg; }}`
  },
})
function WallpaperItem({ file, highlight }) {
  const { height } = options_default2.theme.wallpapers
  let btn
  idle(() =>
    thumbnail(file)
      .then((thumbnail2) => {
        btn.css = `background-image: url('${thumbnail2}');`
      })
      .catch((err) => {
        printerr(err, file)
      })
  )
  return jsx2(Box2, {
    m: "md",
    children: jsx2("button", {
      hexpand: true,
      tooltipText: default2.path_get_basename(file),
      setup: (self) => (btn = self),
      className: highlight.as((h) => cnames("WallpaperButton", h && "highlight")),
      onClicked: () => {
        setWallpaper(file)
        app_default.get_window("launcher").visible = false
      },
      children: jsx2("box", { css: height((h) => `min-height: ${h}pt`) }),
    }),
  })
}
function Wallpaper({ wallpapers, filter: filter2 }) {
  const { columns } = options_default2.theme.wallpapers
  return jsxs(Box2, {
    vertical: true,
    pb: "2xl",
    children: [
      jsx2(Separator, { mb: "md" }),
      jsx2(AccentPicker, {}),
      jsx2(Separator, { m: "md" }),
      jsx2(Box2, {
        px: "2xl",
        vertical: true,
        children: columns((c) =>
          chunks(c, wallpapers)
            .filter((row) => row.length === columns.get())
            .map((row) => jsx2("box", { homogeneous: true, children: row.map((w) => jsx2(WallpaperItem, { file: w, highlight: filter2((f) => f.includes(w)) })) }))
        ),
      }),
    ],
  })
}
var init_Wallpaper = __esm({
  async "src/gtk3/src/launcher/plugins/theme/Wallpaper.tsx"() {
    await init_gtk3()
    await init_gjs()
    init_Box()
    await init_Separator()
    init_utils2()
    init_utils()
    init_array()
    init_theme()
    init_swww()
    await init_AccentPicker()
    init_options2()
    init_jsx_runtime()
    void scss`.Launcher .WallpaperButton { all: unset; transition: $transition; background-size: cover; background-position: center; border-radius: $radius; @if $shadows { box-shadow: 0 0 4pt 0 $shadow-color, inset 0 0 0 $border-width $border-color; } &.highlight { @if $shadows { box-shadow: 0 0 4pt 0 $shadow-color, inset 0 0 0 $border-width $success; } @else { box-shadow: inset 0 0 0 $border-width $success; } } &:focus, &:hover { @if $shadows { box-shadow: 0 0 4pt 0 $shadow-color, inset 0 0 0 $border-width $primary; } @else { box-shadow: inset 0 0 0 $border-width $primary; } }}`
  },
})
function sh4() {
  if (!dependencies("fzf")) {
    throw Error("missing dependency: fzf")
  }
  const dir = mkdir(options_default2.theme.wallpapers.directory.get())
  const filter2 = Variable([])
  return {
    description: "Set the wallpaper",
    icon: DarkMode(),
    ui: Wallpaper({ wallpapers: ls(dir).map((f) => `${dir}/${f}`), filter: filter2 }),
    search(search) {
      if (!search) return filter2.set([])
      bash`echo "${ls(dir).join("\n")}" | fzf -f "${search}"`.then((out) => filter2.set(out.split("\n").map((f) => `${dir}/${f}`))).catch(() => filter2.set([]))
    },
    enter(entered) {
      if (!entered) return
      bash`echo "${ls(dir).join("\n")}" | fzf -f "${entered}" | head -n 1`.then((out) => setWallpaper(`${dir}/${out}`)).catch(() => 0)
    },
  }
}
var init_theme2 = __esm({
  async "src/gtk3/src/launcher/plugins/theme/index.ts"() {
    init_os()
    await init_gjs()
    init_options2()
    await init_DarkMode()
    await init_Wallpaper()
    init_swww()
  },
})
import Wp from "gi://AstalWp"
function MixerItem({ stream }) {
  const { mixer } = options_default2.audio
  return jsxs(Box2, {
    px: "2xl",
    gap: "md",
    className: "MixerItem",
    vexpand: false,
    children: [
      jsx2(Icon2, { symbolic: true, size: 1.4, icon: bind(stream, "description").as((s) => s.toLowerCase()) }),
      jsxs(Box2, {
        vertical: true,
        gap: "md",
        children: [
          jsx2("box", { visible: mixer.names(), children: jsx2("label", { className: "name", truncate: true, halign: START, label: bind(stream, "name") }) }),
          jsx2(Slider2, { onDragged: ({ value }) => (stream.volume = value), value: bind(stream, "volume") }),
        ],
      }),
    ],
  })
}
function SinkItem(stream) {
  return jsx2(Box2, {
    px: "2xl",
    className: "SinkItem",
    children: jsx2(Button2, {
      hfill: true,
      onClicked: () => (stream.isDefault = true),
      children: jsxs(Box2, {
        px: "2xl",
        py: "xl",
        children: [
          jsx2(Icon2, { symbolic: true, className: "primary", css: "margin-right: .3em", fallback: "audio-speakers", icon: bind(stream, "icon") }),
          jsx2("label", { truncate: true, hexpand: true, halign: START, label: bind(stream, "description") }),
          jsx2(Icon2, { symbolic: true, className: "primary", css: "margin-left: .3em", halign: END, visible: bind(stream, "isDefault"), icon: "object-select" }),
        ],
      }),
    }),
  })
}
function Mixer(filter2) {
  const wp = Wp.get_default().audio
  return jsxs(Box2, {
    vertical: true,
    className: "Mixer",
    children: [
      jsx2(Separator, {}),
      jsxs(Box2, {
        vexpand: false,
        p: "2xl",
        mx: "lg",
        children: [
          jsx2(Icon2, { symbolic: true, css: "margin-right: .3em", icon: bind(wp.defaultSpeaker, "icon") }),
          jsx2(Slider2, { onDragged: ({ value }) => (wp.defaultSpeaker.volume = value), value: bind(wp.defaultSpeaker, "volume") }),
        ],
      }),
      jsx2(Separator, {}),
      jsx2(Box2, {
        vertical: true,
        gap: "2xl",
        py: "2xl",
        px: "lg",
        children: bind(wp, "streams").as((ss) =>
          ss.length > 0
            ? ss.map((s) => jsx2("box", { visible: filter2((f) => f.includes(s.name.toLowerCase())), children: jsx2(MixerItem, { stream: s }) }))
            : jsx2("box", { halign: CENTER, children: "No audio playing" })
        ),
      }),
      jsx2(Separator, {}),
      jsx2(Box2, { vertical: true, gap: "2xl", py: "2xl", children: bind(wp, "speakers").as((ss) => ss.map(SinkItem)) }),
    ],
  })
}
var init_Mixer = __esm({
  async "src/gtk3/src/launcher/plugins/audio/Mixer.tsx"() {
    init_Box()
    await init_Separator()
    await init_Slider()
    init_Button()
    await init_Icon()
    init_theme()
    await init_gjs()
    init_options2()
    init_jsx_runtime()
    void scss`.Launcher .Mixer { .MixerItem { icon { font-size: 1.6em; } }}`
  },
})
import Wp2 from "gi://AstalWp"
function bluetooth() {
  if (!dependencies("fzf")) {
    throw Error("missing dependency: fzf")
  }
  const wp = Wp2.get_default().audio
  const names = () => wp.get_streams().map((s) => s.name.toLowerCase())
  const filter2 = Variable(names())
  return {
    icon: "mixer-symbolic",
    ui: Mixer(filter2),
    description: "Audio mixer",
    search(search) {
      bash`echo "${names().join("\n")}" | fzf -f "${search}"`.then((out) => out && filter2.set(out.split("\n"))).catch(() => {})
    },
    enter() {},
  }
}
var init_audio = __esm({
  async "src/gtk3/src/launcher/plugins/audio/index.ts"() {
    init_os()
    await init_gjs()
    await init_Mixer()
  },
})
import Bluetooth from "gi://AstalBluetooth"
function BtIcon({ bt }) {
  const icon2 = bind(bt, "powered").as((p) => (p ? "bluetooth-active" : "bluetooth-disabled"))
  const discover = () => {
    if (bt.powered) {
      bt.start_discovery()
      timeout(1e4, () => {
        bt.stop_discovery()
      })
    }
  }
  return jsxs("box", {
    setup: discover,
    children: [
      jsx2("revealer", { transitionType: SLIDE_LEFT, revealChild: bind(bt, "discovering"), children: jsx2(Box2, { mr: "sm", children: jsx2(Spinner, { className: "primary" }) }) }),
      jsx2(ToggleButton, {
        vfill: true,
        suggested: true,
        color: "primary",
        state: bind(bt, "powered"),
        onToggled: () => {
          bt.powered = !bt.powered
          discover()
        },
        children: jsx2(Box2, { px: "xl", children: jsx2(Icon2, { symbolic: true, icon: icon2 }) }),
      }),
    ],
  })
}
function BluetoothIcon() {
  const bt = Bluetooth.get_default()
  return jsx2("box", { children: bind(bt, "adapter").as((bt2) => bt2 && jsx2(BtIcon, { bt: bt2 })) })
}
var init_BluetoothIcon = __esm({
  async "src/gtk3/src/launcher/plugins/bluetooth/BluetoothIcon.tsx"() {
    await init_gjs()
    await init_ToggleButton()
    init_Box()
    await init_Spinner()
    await init_Icon()
    init_jsx_runtime()
  },
})
import BT from "gi://AstalBluetooth"
function Device({ device }) {
  const bt = BT.get_default()
  const connected = bind(device, "connected")
  const connecting = bind(device, "connecting")
  function onClicked() {
    bt.adapter.powered = true
    if (!device.connecting && !device.connected) device.connect_device(null)
    else device.disconnect_device(null)
  }
  return jsx2(FlatButton, {
    onClicked: onClicked,
    color: connected.as((c) => (c ? "success" : "primary")),
    children: jsxs(Box2, {
      px: "2xl",
      m: "lg",
      children: [
        jsx2(Icon2, { symbolic: true, icon: bind(device, "icon") }),
        jsx2("label", { label: bind(device, "alias"), css: "margin-left: .3em" }),
        jsx2("box", { hexpand: true }),
        jsx2("revealer", { transitionType: SLIDE_LEFT, revealChild: connected, children: jsx2("label", { className: "flat", label: "connected" }) }),
        jsx2("revealer", { transitionType: SLIDE_LEFT, revealChild: connecting, children: jsx2(Spinner, {}) }),
      ],
    }),
  })
}
function Bluetooth2(filter2) {
  const bt = BT.get_default()
  return jsx2(Box2, {
    vertical: true,
    pb: "xl",
    children: bind(bt, "devices").as((ds) =>
      ds
        .filter((d) => d.name)
        .map((d) =>
          jsx2("revealer", {
            transitionType: SLIDE_DOWN,
            revealChild: filter2((f) => f.includes(d.name.toLowerCase())),
            children: jsxs("box", { vertical: true, children: [jsx2(Separator, {}), jsx2(Device, { device: d })] }),
          })
        )
    ),
  })
}
var init_Bluetooth = __esm({
  async "src/gtk3/src/launcher/plugins/bluetooth/Bluetooth.tsx"() {
    await init_gjs()
    await init_Icon()
    init_Box()
    init_FlatButton()
    await init_Separator()
    await init_Spinner()
    init_jsx_runtime()
  },
})
import BT2 from "gi://AstalBluetooth"
function bluetooth2() {
  if (!dependencies("fzf")) {
    throw Error("missing dependency: fzf")
  }
  const bt = BT2.get_default()
  const names = () => bt.get_devices().map((d) => d.name.toLowerCase())
  const filter2 = Variable(names())
  return {
    icon: BluetoothIcon(),
    ui: Bluetooth2(filter2),
    description: "Connect to Bluetooth devices",
    search(search) {
      bash`echo "${names().join("\n")}" | fzf -f "${search}"`.then((out) => out && filter2.set(out.split("\n"))).catch(() => {})
    },
    enter() {},
    complete(search) {
      const res = exec(["bash", "-c", `cat ${names()} | fzf -f "${search}" | head -n 1`])
      return res === search ? "" : res
    },
  }
}
var init_bluetooth = __esm({
  async "src/gtk3/src/launcher/plugins/bluetooth/index.ts"() {
    await init_BluetoothIcon()
    await init_Bluetooth()
    await init_gjs()
    init_os()
  },
})
function plugins() {
  const o = options_default2
  return variable_default.derive(
    [
      o.hyprland.enable,
      o.hyprland.prefix,
      o.nix.enable,
      o.nix.prefix,
      o.sh.enable,
      o.sh.prefix,
      o.music.enable,
      o.music.prefix,
      o.powermenu.enable,
      o.powermenu.prefix,
      o.notifications.enable,
      o.notifications.prefix,
      o.calendar.enable,
      o.calendar.prefix,
      o.wifi.enable,
      o.wifi.prefix,
      o.audio.enable,
      o.audio.prefix,
      o.theme.enable,
      o.theme.prefix,
      o.bluetooth.enable,
      o.bluetooth.prefix,
      o.dock.enable,
    ],
    () => ({
      [o.nix.prefix.get()]: o.nix.enable.get() ? mkPlugin(nix) : null,
      [o.sh.prefix.get()]: o.sh.enable.get() ? mkPlugin(sh2) : null,
      [o.audio.prefix.get()]: o.audio.enable.get() ? mkPlugin(bluetooth) : null,
      [o.wifi.prefix.get()]: o.wifi.enable.get() ? mkPlugin(sh3) : null,
      [o.bluetooth.prefix.get()]: o.bluetooth.enable.get() ? mkPlugin(bluetooth2) : null,
      [o.hyprland.prefix.get()]: o.hyprland.enable.get() ? mkPlugin(hyprland) : null,
      [o.music.prefix.get()]: o.music.enable.get() ? mkPlugin(media) : null,
      [o.powermenu.prefix.get()]: o.powermenu.enable.get() ? mkPlugin(powermenu) : null,
      [o.notifications.prefix.get()]: o.notifications.enable.get() ? mkPlugin(notifications) : null,
      [o.calendar.prefix.get()]: o.calendar.enable.get() ? mkPlugin(calendar) : null,
      [o.theme.prefix.get()]: o.theme.enable.get() ? mkPlugin(sh4) : null,
      dock: o.dock.enable.get() ? mkPlugin(dock) : null,
      default: mkPlugin(plug),
    })
  )
}
function mkPlugin(pluginCtor) {
  const { icon: icon2, ui, ...plugin } = pluginCtor()
  const visible = variable_default(false)
  idle(plugin.reload)
  return {
    ...plugin,
    complete: plugin.complete ?? (() => ""),
    visible(v) {
      visible.set(v)
    },
    icon:
      icon2 &&
      jsx2("revealer", {
        revealChild: visible(),
        transitionType: SLIDE_LEFT,
        children:
          icon2 instanceof Gtk5.Widget
            ? icon2
            : jsx2(Box2, {
                pr: "xl",
                children: jsx2(Icon2, { symbolic: true, className: typeof icon2 === "object" ? (icon2.color ?? "primary") : "primary", icon: typeof icon2 === "object" ? icon2.icon : icon2 }),
              }),
      }),
    ui: jsx2("revealer", { revealChild: visible(), transitionType: SLIDE_DOWN, children: ui }),
  }
}
var init_plugin = __esm({
  async "src/gtk3/src/launcher/plugins/plugin.tsx"() {
    await init_gtk3()
    init_time()
    init_variable()
    init_Box()
    init_options2()
    await init_dock()
    await init_default()
    await init_nix()
    await init_hyprland2()
    await init_sh()
    await init_media()
    await init_powermenu()
    await init_notifications()
    await init_calendar()
    await init_wifi()
    await init_theme2()
    await init_audio()
    await init_bluetooth()
    init_theme()
    await init_Icon()
    init_jsx_runtime()
    void scss`.Launcher icon { &.regular { color: $fg; } &.primary { color: $primary; } &.success { color: $success; } &.error { color: $error; }}`
  },
})
function hide() {
  app_default.get_window("launcher").hide()
}
function Launcher() {
  const plugs = plugins()
  const { separator, width, margin } = options_default2
  const showHelp = Variable(false)
  const text = Variable("")
  const position = Variable(0)
  function hidePlugins() {
    Object.values(plugs.get()).map((p) => p?.visible(false))
  }
  function setText(str) {
    text.set(str)
    position.set(str.length)
  }
  function handler({ text: text2, enter, complete }) {
    const plugins2 = plugs.get()
    const help2 = () => {
      hidePlugins()
      showHelp.set(true)
      if (enter) hide()
    }
    if (text2 === "") {
      hidePlugins()
      showHelp.set(false)
      plugins2.dock?.visible(true)
      if (enter) hide()
    } else if (text2 === "?" || text2 === ":") {
      help2()
    } else if (text2?.startsWith(":")) {
      showHelp.set(false)
      const index = text2.indexOf(" ")
      const prefix = text2.substring(1, index)
      const search = text2.substring(index).trim()
      const plugin = plugins2[prefix]
      if (plugin) {
        if (enter) {
          plugin.enter(search)
        } else if (complete && plugin.complete) {
          const res = plugin.complete(search)
          if (res != "") {
            setText(`:${prefix} ${plugin.complete(search)}`)
            return true
          }
        } else {
          plugin.search(search)
          plugin.visible(true)
        }
      } else {
        help2()
      }
    } else {
      plugins2.dock?.visible(false)
      plugins2.default.visible(true)
      if (enter) {
        plugins2.default.enter(text2)
      } else if (complete && plugins2.default.complete) {
        const c = plugins2.default.complete(text2)
        if (c !== "") {
          setText(c)
          return true
        }
      } else {
        plugins2.default.search(text2)
      }
    }
  }
  function selectPlugin(prefix) {
    setText(`:${prefix} `)
  }
  function setup(self) {
    self.connect("notify::visible", ({ visible }) => {
      if (!visible) {
        Object.values(plugs.get()).map((p) => p?.reload?.())
        setText("")
      }
    })
    handler({ text: "" })
  }
  const win = jsx2("window", {
    namespace: "launcher",
    css: "background-color: transparent",
    name: "launcher",
    application: app_default,
    anchor: Astal7.WindowAnchor.TOP | Astal7.WindowAnchor.BOTTOM,
    exclusivity: Astal7.Exclusivity.IGNORE,
    keymode: Astal7.Keymode.ON_DEMAND,
    setup: setup,
    onKeyPressEvent: function (_, event) {
      if (event.get_keyval()[1] === Gdk.KEY_Escape) hide()
    },
    children: jsxs("box", {
      children: [
        jsx2(PopupPadding, { h: true, onClick: hide, width: 100 }),
        jsxs("box", {
          vertical: true,
          children: [
            jsx2(PopupPadding, { onClick: hide, children: jsx2("box", { css: margin((s) => `min-height: ${s}pt`) }) }),
            jsx2(PopupBin, {
              r: "md",
              children: jsxs("box", {
                vertical: true,
                className: separator((s) => `Launcher separator-${s}`),
                children: [
                  jsx2(Search, {
                    text: text,
                    position: position,
                    handler: handler,
                    children: plugs((plugins2) =>
                      Object.values(plugins2)
                        .filter((i) => i?.icon)
                        .map((i) => i.icon)
                    ),
                  }),
                  jsxs("box", {
                    vertical: true,
                    className: "Body",
                    css: width((s) => `min-width: ${s}pt`),
                    children: [
                      jsx2(Help_default, { plugins: plugs, visible: showHelp(), onClicked: selectPlugin }),
                      plugs((plugins2) =>
                        Object.values(plugins2)
                          .filter((i) => i?.ui)
                          .map((i) => i.ui)
                      ),
                    ],
                  }),
                ],
              }),
            }),
            jsx2(PopupPadding, { v: true, onClick: hide }),
          ],
        }),
        jsx2(PopupPadding, { h: true, onClick: hide, width: 100 }),
      ],
    }),
  })
  return Object.assign(win, { setText: setText })
}
var init_Launcher = __esm({
  async "src/gtk3/src/launcher/Launcher.tsx"() {
    await init_gtk3()
    await init_gjs()
    init_PopupBin()
    init_PopupPadding()
    await init_Search()
    await init_Help()
    init_options2()
    await init_plugin()
    init_theme()
    init_jsx_runtime()
    void scss`.Launcher { &.separator-padded separator { margin-left: $padding; margin-right: $padding; } &.separator-none separator { min-height: 0; background-color: transparent; }}`
  },
})
var launcher_exports = {}
__export(launcher_exports, { default: () => launcher })
function launcher() {
  const launcher2 = Launcher()
  Object.assign(globalThis, {
    launcher(prefix) {
      launcher2.show()
      launcher2.setText(`:`)
      if (prefix) launcher2.setText(`:${prefix} `)
    },
  })
  if (options_default.hyprland.enable.get()) {
    import("gi://AstalHyprland").then((m) => {
      const h = m.default.get_default()
      h.message_async("keyword layerrule noanim,launcher", null)
    })
  }
}
var init_launcher = __esm({
  async "src/gtk3/src/launcher/index.ts"() {
    await init_Launcher()
    init_options()
  },
})
function PanelButton({ child, className = "", ...props }) {
  return jsx2(Button2, { vfill: true, m: "md", className: fake(className).as((cn) => `PanelButton ${cn}`), ...props, children: jsx2(Box2, { py: "md", px: "xl", children: child }) })
}
var init_PanelButton = __esm({
  "src/gtk3/src/bar/PanelButton.tsx"() {
    init_Button()
    init_Box()
    init_utils()
    init_jsx_runtime()
  },
})
import GLib9 from "gi://GLib"
var options_default3
var init_options3 = __esm({
  "src/gtk3/src/bar/options.ts"() {
    init_option()
    options_default3 = mkOptions("bar", {
      bold: opt(true),
      position: opt("top"),
      corners: opt("md"),
      transparent: opt(false),
      layout: {
        start: opt(["launcher", "workspaces", "taskbar", "spacer", "messages"]),
        center: opt(["date"]),
        end: opt(["media", "spacer", "systray", "screenrecord", "system", "battery", "powermenu"]),
      },
      launcher: { suggested: opt(false), flat: opt(true), icon: opt(GLib9.get_os_info("LOGO") || "system-search-symbolic"), label: opt("Applications"), action: opt("astal -t launcher") },
      date: { flat: opt(true), format: opt("%H:%M - %A %e."), action: opt(`astal eval "launcher('cal')"`) },
      battery: { suggested: opt(true), flat: opt(true), bar: opt("regular"), percentage: opt(true), low: opt(30), size: opt("md") },
      workspaces: { flat: opt(true), workspaces: opt(7), action: opt(`astal eval "launcher('h')"`) },
      taskbar: { flat: opt(true), monochrome: opt(true) },
      messages: { flat: opt(true), action: opt(`astal eval "launcher('n')"`) },
      systray: { flat: opt(true), ignore: opt(["KDE Connect Indicator", "spotify-client"]) },
      media: { flat: opt(true), monochrome: opt(true), preferred: opt("spotify"), direction: opt("right"), format: opt("{artist} - {title}"), maxChars: opt(40), timeout: opt(5e3) },
      powermenu: { suggested: opt(true), flat: opt(true), action: opt("astal -t powermenu") },
      systemIndicators: { flat: opt(true), action: opt(`astal eval "launcher('a')"`) },
    })
  },
})
function Date_default() {
  const now = () => default2.DateTime.new_now_local()
  const date = Variable(now()).poll(1e3, now)
  const { action, format: format2, flat: flat3 } = options_default3.date
  const time3 = Variable.derive([date, format2], (c, f) => c.format(f) || "")
  return jsx2(PanelButton, {
    flat: flat3(),
    onDestroy: () => {
      date.drop()
      time3.drop()
    },
    tooltipText: action(),
    onClicked: () => sh(action.get()),
    children: jsx2("label", { label: time3() }),
  })
}
var init_Date = __esm({
  async "src/gtk3/src/bar/buttons/Date.tsx"() {
    init_PanelButton()
    init_options3()
    await init_gjs()
    init_os()
    init_jsx_runtime()
  },
})
function Launcher2() {
  const { icon: icon2, label, action, flat: flat3, suggested: suggested2 } = options_default3.launcher
  return jsx2(PanelButton, {
    suggested: suggested2(),
    flat: flat3(),
    color: "primary",
    className: "Launcher",
    tooltipText: action(),
    onClicked: () => sh(action.get()),
    children: jsxs(Box2, { gap: "md", children: [jsx2("icon", { visible: icon2(Boolean), icon: icon2() }), jsx2("label", { visible: label(Boolean), label: label() })] }),
  })
}
var init_Launcher2 = __esm({
  "src/gtk3/src/bar/buttons/Launcher.tsx"() {
    init_Box()
    init_PanelButton()
    init_options3()
    init_os()
    init_jsx_runtime()
  },
})
import Hyprland4 from "gi://AstalHyprland"
function workspace(id) {
  const hyprland2 = Hyprland4.get_default()
  const get = () => hyprland2.get_workspace(id) || Hyprland4.Workspace.dummy(id, null)
  return Variable(get()).observe(hyprland2, "workspace-added", get).observe(hyprland2, "workspace-removed", get)
}
function Workspace(id) {
  const hyprland2 = Hyprland4.get_default()
  const ws = workspace(id)
  const className = Variable.derive([bind(hyprland2, "focusedWorkspace"), bind(hyprland2, "clients"), ws], (focused, clients, ws2) =>
    cnames("Workspace", focused === ws2 && "focused", clients.filter((c) => c.workspace == ws2).length > 0 ? "occupied" : "empty")
  )
  return jsx2("label", {
    onDestroy: () => {
      className.drop()
      ws.drop()
    },
    valign: CENTER,
    className: className(),
    label: `${id}`,
  })
}
function Workspaces() {
  const { flat: flat3, workspaces, action } = options_default3.workspaces
  const hyprland2 = Hyprland4.get_default()
  const scroll = throttle(200, (y) => hyprland2.dispatch("workspace", y > 0 ? "m+1" : "m-1"))
  return jsx2(PanelButton, {
    flat: flat3(),
    className: "Workspaces",
    tooltipText: action(),
    onScroll: (_, { delta_y }) => scroll(delta_y),
    onClicked: () => sh(action.get()),
    children: jsx2(Box2, { gap: "md", children: workspaces((n) => range(1, n).map(Workspace)) }),
  })
}
var init_Workspaces = __esm({
  async "src/gtk3/src/bar/buttons/Workspaces.tsx"() {
    await init_gjs()
    init_PanelButton()
    init_options3()
    init_Box()
    init_theme()
    init_os()
    init_array()
    init_function()
    init_utils()
    init_jsx_runtime()
    void scss`.Bar { .panel.transparent .PanelButton.Workspaces label.Workspace { box-shadow: $box-shadow; } .panel:not(.transparent) .PanelButton.Workspaces label.Workspace { box-shadow: inset 0 0 0 $border-width $border-color; } .PanelButton.Workspaces { label.Workspace { border-radius: $radius * .8; color: transparent; font-size: 0; transition: $transition * .5; &.empty { background-color: transparentize($fg, .78); min-height: .3rem; min-width: .3rem; } &.occupied { background-color: $fg; min-height: .5rem; min-width: .5rem; } &.focused { background-color: $primary; min-height: 1rem; min-width: 1.6rem; } } &:active label.Workspace.focused { background-color: $accent-fg; } }}`
  },
})
function PowerMenu2() {
  const { flat: flat3, suggested: suggested2, action } = options_default3.powermenu
  return jsx2(PanelButton, {
    flat: flat3(),
    suggested: suggested2(),
    color: "error",
    tooltipText: action(),
    onClicked: () => sh(action.get()),
    children: jsx2(Icon2, { symbolic: true, icon: "system-shutdown" }),
  })
}
var init_PowerMenu2 = __esm({
  async "src/gtk3/src/bar/buttons/PowerMenu.tsx"() {
    await init_Icon()
    init_PanelButton()
    init_options3()
    init_os()
    init_jsx_runtime()
  },
})
import Hyprland5 from "gi://AstalHyprland"
function Client2(client) {
  const { flat: flat3, monochrome: monochrome2 } = options_default3.taskbar
  const hyprland2 = Hyprland5.get_default()
  const focused = bind(hyprland2, "focusedClient").as((c) => c === client)
  return jsx2(PanelButton, {
    flat: flat3(),
    suggested: focused,
    color: focused.as((f) => (f ? "primary" : "regular")),
    tooltipText: bind(client, "title"),
    onClicked: () => client.focus(),
    children: jsx2(Icon2, { className: focused.as((f) => (f ? "focused" : "")), fallback: "application-x-executable", symbolic: monochrome2(), icon: bind(client, "class") }),
  })
}
function Taskbar_default() {
  const hyprland2 = Hyprland5.get_default()
  return jsx2("box", { className: "Taskbar", children: bind(hyprland2, "clients").as((cs) => cs.sort((a, b) => a.workspace.id - b.workspace.id).map(Client2)) })
}
var init_Taskbar = __esm({
  async "src/gtk3/src/bar/buttons/Taskbar.tsx"() {
    await init_Icon()
    init_PanelButton()
    await init_gjs()
    init_options3()
    init_jsx_runtime()
  },
})
import Battery from "gi://AstalBattery"
function blocks(s) {
  if (s === "sm") return 6
  if (s === "md") return 8
  if (s === "lg") return 10
  return 4
}
function Battery_default() {
  const battery = Battery.get_default()
  const style = Variable.derive([bind(battery, "charging"), bind(battery, "percentage"), low], (ch, p, low2) => (ch ? "success" : p * 100 <= low2 ? "error" : "regular"))
  const names = Variable.derive([style, size, bar], (...s) => cnames("Battery", ...s))
  return jsx2(PanelButton, {
    flat: flat(),
    suggested: suggested(),
    onDestroy: () => {
      style.drop()
      names.drop()
    },
    className: names(),
    color: style(),
    visible: bind(battery, "isPresent"),
    tooltipText: bind(battery, "percentage").as((p) => `${Math.floor(p * 100)}%`),
    onClicked: () => percentage.set(!percentage.get()),
    children: jsxs("box", {
      children: [
        jsxs("box", { visible: bar((s) => s === "regular"), children: [jsx2(PercentageLabel, {}), jsx2(LevelBar2, {})] }),
        jsxs("box", { visible: bar((s) => s === "hidden"), children: [jsx2(PercentageIcon, {}), jsx2(PercentageLabel, {})] }),
      ],
    }),
  })
}
var flat, suggested, bar, percentage, low, size, PercentageLabel, PercentageIcon, LevelBar2
var init_Battery = __esm({
  async "src/gtk3/src/bar/buttons/Battery.tsx"() {
    await init_Icon()
    init_PanelButton()
    init_options3()
    await init_gtk3()
    await init_gjs()
    init_theme()
    init_utils()
    init_jsx_runtime()
    ;({ flat, suggested, bar, percentage, low, size } = options_default3.battery)
    PercentageLabel = () =>
      jsx2("box", {
        children: jsx2("revealer", {
          clickThrough: true,
          revealChild: percentage(),
          transitionType: SLIDE_RIGHT,
          children: jsx2("label", { label: bind(Battery.get_default(), "percentage").as((p) => `${Math.floor(p * 100)}%`) }),
        }),
      })
    PercentageIcon = () => jsx2(Icon2, { symbolic: true, icon: bind(Battery.get_default(), "percentage").as((p) => (p > 0.98 ? "battery-full-charged" : Battery.get_default().batteryIconName)) })
    LevelBar2 = ({ vfill }) =>
      jsx2("levelbar", {
        valign: vfill ? FILL : CENTER,
        mode: Gtk5.LevelBarMode.DISCRETE,
        minValue: 0,
        maxValue: size(blocks),
        value: bind(Variable.derive([bind(Battery.get_default(), "percentage"), size], (p, s) => p * blocks(s))),
      })
    void scss`@mixin battery($width, $blocks, $shade) { &.regular label { margin-right: $spacing * .3;} &.hidden label { margin-left: $spacing * .2;} &:active { icon, label { color: $bg; }} levelbar { &, * { all: unset; } trough { border: $border; border-radius: $radius; background-color: transparentize($widget-bg, $widget-opacity); } block { min-width: $width; min-height: .8em; &:last-child { border-radius: 0 $radius $radius 0; } &:first-child { border-radius: $radius 0 0 $radius; } } } @for $i from 1 through $blocks { block:nth-child(#{$i}).filled { background-color: color.mix($bg, $primary, $i * $shade) } &:active block:nth-child(#{$i}).filled { background-color: color.mix($bg, $bg, $i * $shade); } &.error block:nth-child(#{$i}).filled { background-color: color.mix($bg, $error, $i * $shade) } &.error:active block:nth-child(#{$i}).filled { background-color: color.mix($bg, $bg, $i * $shade) } &.success block:nth-child(#{$i}).filled { background-color: color.mix($bg, $success, $i * $shade) } &.success:active block:nth-child(#{$i}).filled { background-color: color.mix($bg, $bg, $i * $shade) } }}.Bar { .Battery { &.sm { @include battery(.4em, 6, 6)} &.md { @include battery(.5em, 8, 5)} &.lg { @include battery(.6em, 10, 4)} } .panel.transparent .Battery trough { border: none; box-shadow: $box-shadow; } .panel:not(.transparent) .Battery trough { border: $border; box-shadow: none; }}`
  },
})
import Mpris4 from "gi://AstalMpris"
function Player(player, reveal) {
  let cancel = false
  const label = Variable.derive([format, bind(player, "metadata")], (f) =>
    f.replace("{title}", player.title).replace("{artist}", player.artist).replace("{album}", player.album).replace("{identity}", player.identity)
  )
  const Revealer2 = ({ child }) =>
    jsx2("revealer", {
      setup: (self) =>
        self.hook(player, "notify::title", () => {
          const time3 = tout.get()
          if (time3 > 0) {
            self.revealChild = true
            timeout(time3, () => {
              if (!reveal.get() && !cancel) self.revealChild = false
            })
          }
        }),
      revealChild: reveal(),
      transitionType: direction((d) => (d === "left" ? SLIDE_LEFT : SLIDE_RIGHT)),
      children: child,
    })
  return jsxs("box", {
    onDestroy: () => {
      label.drop()
      cancel = true
    },
    children: [
      jsxs("box", {
        visible: direction((d) => d == "left"),
        children: [
          jsx2(Revealer2, { children: jsx2(Box2, { mx: "md", css: "margin-left: 0", children: jsx2("label", { label: label(), maxWidthChars: maxChars(), truncate: true }) }) }),
          jsx2(Icon2, { symbolic: monochrome(), icon: bind(player, "entry"), fallback: "audio-x-generic" }),
        ],
      }),
      jsxs("box", {
        visible: direction((d) => d == "right"),
        children: [
          jsx2(Icon2, { symbolic: monochrome(), icon: bind(player, "entry"), fallback: "audio-x-generic" }),
          jsx2(Revealer2, { children: jsx2(Box2, { mx: "md", css: "margin-right: 0", children: jsx2("label", { label: label(), maxWidthChars: maxChars(), truncate: true }) }) }),
        ],
      }),
    ],
  })
}
function Media_default() {
  const mpris = Mpris4.get_default()
  const reveal = Variable(false)
  const player = Variable.derive([bind(mpris, "players"), preferred], (ps, pref) => ps.find((p) => p.busName?.includes(pref)) || ps?.[0] || null)
  return jsx2(PanelButton, {
    flat: flat2(),
    onDestroy: () => player.drop(),
    onClicked: () => player.get()?.play_pause(),
    onHoverLost: throttle(100, () => reveal.set(false)),
    onHover: throttle(100, () => reveal.set(true)),
    visible: player(Boolean),
    children: player((p) => p && Player(p, reveal)),
  })
}
var flat2, preferred, monochrome, direction, format, maxChars, tout
var init_Media2 = __esm({
  async "src/gtk3/src/bar/buttons/Media.tsx"() {
    await init_Icon()
    init_Box()
    init_PanelButton()
    await init_gjs()
    init_function()
    init_options3()
    init_jsx_runtime()
    ;({ flat: flat2, preferred, monochrome, direction, format, maxChars, timeout: tout } = options_default3.media)
  },
})
import Tray from "gi://AstalTray"
function Item(item) {
  const { flat: flat3 } = options_default3.systray
  let menu
  function createMenu() {
    if (menu) menu.destroy()
    menu = Gtk5.Menu.new_from_model(item.menuModel)
    menu.insert_action_group("dbusmenu", item.actionGroup)
  }
  function setup(btn) {
    hook(btn, item, "notify::menu-model", createMenu)
    hook(btn, item, "notify::action-group", createMenu)
    createMenu()
  }
  return jsx2(PanelButton, {
    flat: flat3(),
    tooltipMarkup: bind(item, "tooltipMarkup"),
    setup: setup,
    onDestroy: () => {
      menu.destroy()
    },
    onClickRelease: (self) => {
      menu.popup_at_widget(self, Gdk.Gravity.SOUTH, Gdk.Gravity.NORTH, null)
    },
    children: jsx2("icon", { gicon: bind(item, "gicon") }),
  })
}
function SysTray_default() {
  const items = Variable.derive([bind(Tray.get_default(), "items"), options_default3.systray.ignore], (items2, ignore) => items2.filter((i) => !ignore.includes(i.id)))
  return jsx2("box", { onDestroy: () => items.drop(), children: items((items2) => items2.map(Item)) })
}
var init_SysTray = __esm({
  async "src/gtk3/src/bar/buttons/SysTray.tsx"() {
    await init_gtk3()
    await init_gjs()
    init_PanelButton()
    init_options3()
    init_jsx_runtime()
  },
})
import Notifd5 from "gi://AstalNotifd"
import PowerProfiles from "gi://AstalPowerProfiles"
import Bluetooth3 from "gi://AstalBluetooth"
import Network4 from "gi://AstalNetwork"
import Wp3 from "gi://AstalWp"
function AudioIcon() {
  const speaker = Wp3.get_default().audio.defaultSpeaker
  return jsx2(Icon2, { symbolic: true, icon: bind(speaker, "volumeIcon") })
}
function MicrophoneIcon() {
  const { audio } = Wp3.get_default()
  const mic = audio.defaultMicrophone
  const visible = bind(audio, "recorders").as((rs) => rs.length > 0)
  return jsx2(Icon2, { symbolic: true, visible: visible, icon: bind(mic, "volumeIcon") })
}
function SystemIndicators_default() {
  const power = PowerProfiles.get_default()
  const bluetooth3 = Bluetooth3.get_default()
  const notifd = Notifd5.get_default()
  const audio = Wp3.get_default().audio
  const network = Network4.get_default()
  const { WIFI, WIRED } = Network4.Primary
  const { flat: flat3, action } = options_default3.systemIndicators
  const scroll = throttle(100, (y) => {
    const s = audio.defaultSpeaker
    if (y > 0 && s.volume < 0.05) return (s.volume = 0)
    if (y < 0 && s.volume === 0) return (s.volume = 0.05)
    if (y < 0) {
      if (s.volume + s.volume * 0.05 > 1) s.volume = 1
      else s.volume += s.volume * 0.05
    }
    if (y >= 0 && s.volume > 0) {
      if (s.volume - s.volume * 0.05 < 0) s.volume = 0
      else s.volume -= s.volume * 0.05
    }
  })
  return jsx2(PanelButton, {
    flat: flat3(),
    tooltipText: action(),
    onClicked: () => sh(action.get()),
    onScroll: (_, { delta_y }) => scroll(delta_y),
    children: jsxs(Box2, {
      gap: "md",
      children: [
        jsx2(Icon2, { symbolic: true, visible: bind(bluetooth3, "isPowered"), icon: "bluetooth-active" }),
        jsx2(Icon2, { symbolic: true, visible: bind(notifd, "dontDisturb"), icon: "notifications-disabled" }),
        jsx2(Icon2, { symbolic: true, visible: bind(power, "activeProfile").as((a) => a !== "balanced"), icon: bind(power, "iconName") }),
        bind(network, "wifi").as((wifi) => wifi && jsx2(Icon2, { symbolic: true, icon: bind(wifi, "iconName"), visible: bind(network, "primary").as((p) => p === WIFI) })),
        bind(network, "wired").as((wired) => wired && jsx2(Icon2, { symbolic: true, icon: bind(wired, "iconName"), visible: bind(network, "primary").as((p) => p === WIRED) })),
        jsx2(AudioIcon, {}),
        jsx2(MicrophoneIcon, {}),
      ],
    }),
  })
}
var init_SystemIndicators = __esm({
  async "src/gtk3/src/bar/buttons/SystemIndicators.tsx"() {
    init_Box()
    init_PanelButton()
    await init_gjs()
    init_os()
    init_function()
    init_options3()
    await init_Icon()
    init_jsx_runtime()
  },
})
import Notifd6 from "gi://AstalNotifd"
function Messages() {
  const { flat: flat3, action } = options_default3.messages
  const notifs = bind(Notifd6.get_default(), "notifications")
  return jsx2(PanelButton, {
    flat: flat3(),
    tooltipText: notifs.as((n) => `${n.length} notifications`),
    onClicked: () => sh(action.get()),
    visible: notifs.as((ns) => ns.length > 0),
    children: jsx2(Icon2, { symbolic: true, icon: "mail-unread" }),
  })
}
var init_Messages = __esm({
  async "src/gtk3/src/bar/buttons/Messages.tsx"() {
    await init_Icon()
    await init_gjs()
    init_PanelButton()
    init_options3()
    init_os()
    init_jsx_runtime()
  },
})
import AstalIO from "gi://AstalIO?version=0.1"
function ScreenRecord() {
  const file = `${default2.get_user_runtime_dir()}/marble/recording.json`
  const visible = Variable(false)
  const time3 = Variable(0)
  mkdir(default2.path_get_dirname(file))
  if (!default2.file_test(file, default2.FileTest.EXISTS)) writeFile(file, JSON.stringify({ recording: false, timer: 0 }))
  const monitor = () =>
    readFileAsync(file).then((content) => {
      const { recording, timer } = JSON.parse(content)
      visible.set(recording)
      time3.set(timer)
    })
  const mon = monitorFile(file, monitor)
  return jsx2(PanelButton, {
    visible: visible(),
    color: "error",
    suggested: true,
    onClicked: () => AstalIO.send_message("recording", "stop"),
    setup: monitor,
    onDestroy: () => mon.cancel(),
    children: jsxs("box", { children: [jsx2("label", { label: time3(lengthStr), css: "margin-right: .2em;" }), jsx2(Icon2, { symbolic: true, icon: "media-record" })] }),
  })
}
var init_ScreenRecord = __esm({
  async "src/gtk3/src/bar/buttons/ScreenRecord.tsx"() {
    await init_Icon()
    await init_gjs()
    init_file()
    init_PanelButton()
    init_utils()
    init_os()
    init_jsx_runtime()
  },
})
function Bar(monitor) {
  const lr = Astal7.WindowAnchor.LEFT | Astal7.WindowAnchor.RIGHT
  const top = Astal7.WindowAnchor.TOP | lr
  const bottom = Astal7.WindowAnchor.BOTTOM | lr
  const { transparent, bold, position, layout } = options_default3
  const { start: start2, center, end } = layout
  const className = Variable.derive([transparent, bold], (t2, b) => cnames("panel", { transparent: t2, bold: b }))
  return jsx2("window", {
    className: "Bar",
    name: `bar-${monitor.model}`,
    namespace: "bar",
    application: app_default,
    gdkmonitor: monitor,
    anchor: position((p) => (p === "top" ? top : bottom)),
    exclusivity: Astal7.Exclusivity.EXCLUSIVE,
    onDestroy: () => className.drop(),
    children: jsxs("centerbox", {
      className: className(),
      children: [
        jsx2("box", { hexpand: true, children: start2((s) => s.map((w) => widget2[w]())) }),
        jsx2("box", { halign: CENTER, children: center((c) => c.map((w) => widget2[w]())) }),
        jsx2("box", { hexpand: true, children: end((e) => e.map((w) => widget2[w]())) }),
      ],
    }),
  })
}
var widget2
var init_Bar = __esm({
  async "src/gtk3/src/bar/Bar.tsx"() {
    await init_Date()
    init_Launcher2()
    await init_Workspaces()
    await init_PowerMenu2()
    await init_Taskbar()
    await init_Battery()
    await init_Media2()
    await init_SysTray()
    await init_SystemIndicators()
    await init_Messages()
    await init_ScreenRecord()
    await init_gjs()
    await init_gtk3()
    init_options3()
    init_theme()
    init_utils()
    init_jsx_runtime()
    void scss`.Bar .panel { &.bold label { font-weight: bold; } &:not(.bold) label { font-weight: normal; } &.transparent { background-color: transparent; label { text-shadow: $text-shadow; } icon { -gtk-icon-shadow: $text-shadow; } } &:not(.transparent) { background-color: $bg; label { text-shadow: none; } icon { -gtk-icon-shadow: none; } }}`
    widget2 = {
      battery: Battery_default,
      date: Date_default,
      launcher: Launcher2,
      media: Media_default,
      powermenu: PowerMenu2,
      systray: SysTray_default,
      system: SystemIndicators_default,
      taskbar: Taskbar_default,
      workspaces: Workspaces,
      screenrecord: ScreenRecord,
      messages: Messages,
      spacer: () => jsx2("box", { expand: true }),
    }
  },
})
function Corners(monitor) {
  const { corners, transparent, position } = options_default3
  const className = Variable.derive([corners, position], (c, p) => cnames("Corners", c, p))
  return jsx2("window", {
    clickThrough: true,
    className: className(),
    onDestroy: () => className.drop(),
    name: `corner-${monitor.model}`,
    namespace: "corners",
    application: app_default,
    css: "background-color: transparent",
    setup: (self) => {
      idle(() => (self.clickThrough = true))
    },
    visible: transparent((t2) => !t2),
    anchor: Astal7.WindowAnchor.TOP | Astal7.WindowAnchor.BOTTOM | Astal7.WindowAnchor.LEFT | Astal7.WindowAnchor.RIGHT,
    gdkmonitor: monitor,
    children: jsx2("box", { expand: true, className: "shadow", children: jsx2("box", { expand: true, className: "border", children: jsx2("box", { expand: true, className: "corner" }) }) }),
  })
}
var init_Corners = __esm({
  async "src/gtk3/src/bar/Corners.tsx"() {
    await init_gtk3()
    await init_gjs()
    init_options3()
    init_theme()
    init_utils()
    init_jsx_runtime()
    void scss`@mixin corners($multiplier) { box.border { border-radius: $radius * $multiplier; box-shadow: 0 0 0 ($radius * $multiplier) $bg; } box.corner { border-radius: $radius * $multiplier; }}.Corners { box { transition: $transition; } &.top { box.shadow { margin-bottom: -99px; } box.border { border-top: $border-width solid $bg; } } &.bottom { box.shadow { margin-top: -99px; } box.border { border-bottom: $border-width solid $bg; } } box.shadow { margin-right: -99px; margin-left: -99px; @if $shadows { box-shadow: inset 0 0 1rem 0 $shadow-color; } } box.border { margin-right: 99px; margin-left: 99px; } box.corner { box-shadow: 0 0 0 $border-width $border-color; } &.sm { @include corners(0.6) } &.md { @include corners(1.0) } &.lg { @include corners(1.4) } &.xl { @include corners(1.8) }}`
  },
})
var bar_exports = {}
__export(bar_exports, { default: () => bar_default })
var bar_default
var init_bar = __esm({
  async "src/gtk3/src/bar/index.ts"() {
    await init_gtk3()
    await init_gjs()
    await init_Bar()
    await init_Corners()
    init_options()
    init_options3()
    bar_default = () => {
      const bars = app_default.get_monitors().map(Bar)
      app_default.get_monitors().map(Corners)
      if (options_default.hyprland.enable.get()) {
        import("gi://AstalHyprland").then((m) => {
          const h = m.default.get_default()
          const msg = (s) => h.message_async(s, null)
          msg("keyword layerrule noanim,bar")
          msg("keyword layerrule noanim,corners")
          Variable.derive([options_default.spacing, options_default.hyprland.gapsMultiplier, options_default3.transparent, options_default3.position], (gaps, mul, tr, pos) => {
            const bar2 = bars[0].get_allocated_height()
            const gap = gaps * mul
            const r = gap > bar2 ? -bar2 : -(gap * 0.9)
            const top = pos == "top" && tr ? r : 0
            const bottom = pos == "bottom" && tr ? r : 0
            for (const { name } of h.get_monitors()) {
              const addr = `addreserved,${top},${bottom},0,0`
              msg(`keyword monitor ${name},${addr}`)
            }
          })
        })
      }
    }
  },
})
var options_default4
var init_options4 = __esm({
  "src/gtk3/src/powermenu/options.ts"() {
    init_option()
    options_default4 = mkOptions("powermenu", {
      layout: opt("1x4"),
      labels: opt(true),
      iconSize: opt(4),
      sleep: opt("systemctl suspend"),
      reboot: opt("systemctl reboot"),
      logout: opt("hyprctl dispatch exit"),
      shutdown: opt("shutdown now"),
    })
  },
})
function PopupWindow({ name, child, shade = false, visible = false, className = "", namespace = "PopupWindow", ...props }) {
  const hide2 = () => (app_default.get_window(name).visible = false)
  const names = derive([fake(className), fake(shade)], (cn, shade2) => cnames("PopupWindow", cn, { shade: shade2 }))
  return jsx2("window", {
    className: names(),
    namespace: namespace,
    visible: visible,
    name: name,
    application: app_default,
    exclusivity: Astal7.Exclusivity.IGNORE,
    keymode: Astal7.Keymode.EXCLUSIVE,
    anchor: Astal7.WindowAnchor.TOP | Astal7.WindowAnchor.BOTTOM,
    onKeyPressEvent: function (_, event) {
      if (event.get_keyval()[1] === Gdk.KEY_Escape) hide2()
    },
    ...props,
    children: jsxs("box", {
      children: [
        jsx2(PopupPadding, { h: true, onClick: hide2, width: 100 }),
        jsxs("box", { vertical: true, children: [jsx2(PopupPadding, { v: true, onClick: hide2 }), child, jsx2(PopupPadding, { v: true, onClick: hide2 })] }),
        jsx2(PopupPadding, { h: true, onClick: hide2, width: 100 }),
      ],
    }),
  })
}
var init_PopupWindow = __esm({
  async "lib/gtk3/src/primitive/PopupWindow.tsx"() {
    await init_gtk3()
    init_PopupPadding()
    init_theme()
    await init_gjs()
    init_utils()
    init_jsx_runtime()
    void scss`.PopupWindow { all: unset; border: none; box-shadow: none; &.shade { background-color: rgba(0,0,0,.4); }}`
  },
})
function PowerButton2({ icon: icon2, label, onClick }) {
  const { labels, iconSize } = options_default4
  return jsx2(Box2, {
    p: "2xl",
    children: jsx2("button", {
      expand: true,
      className: labels((labels2) => cnames({ labels: labels2 }, "PowerButton")),
      onClicked: onClick,
      children: jsxs(Box2, { gap: "sm", vertical: true, children: [jsx2(Icon2, { symbolic: true, icon: icon2, size: iconSize() }), jsx2("label", { visible: labels(), label: label })] }),
    }),
  })
}
var init_PowerButton = __esm({
  async "src/gtk3/src/powermenu/PowerButton.tsx"() {
    init_Box()
    await init_Icon()
    init_theme()
    init_utils()
    init_options4()
    init_jsx_runtime()
    void scss`window#powermenu .PowerButton { all: unset; background-color: transparent; box-shadow: none; outline: none; &.labels { margin-bottom: -.5em; } icon { color: $fg; border-radius: $radius * 2.4; transition: $transition; background-color: transparentize($widget-bg, $widget-opacity); border: $border; padding: $padding * 2; } label { color: transparentize($fg, .1); font-weight: lighter; } &:hover { icon { -gtk-icon-transform: scale(0.94); background-color: transparentize($fg, $hover-opacity); } label { color: $fg; } } &:focus { icon { -gtk-icon-transform: scale(0.94); background-color: transparentize($fg, $hover-opacity); border-color: $primary } label { color: $primary; } } &:active { icon { color: $bg; background-color: $primary; } }}`
  },
})
function PowerMenu3({ onClick }) {
  return jsx2(PopupWindow, {
    shade: true,
    name: "powermenu",
    children: jsx2(PopupBin, {
      valign: CENTER,
      vexpand: false,
      r: "4xl",
      p: "2xl",
      children: jsx2(Box2, { m: "2xl", p: "lg", children: options_default4.layout((l) => (l === "1x4" ? jsx2(LineLayout, { onClick: onClick }) : jsx2(BoxLayout, { onClick: onClick }))) }),
    }),
  })
}
var Shutdown, LogOut, Reboot, Sleep, LineLayout, BoxLayout
var init_PowerMenu3 = __esm({
  async "src/gtk3/src/powermenu/PowerMenu.tsx"() {
    init_Box()
    init_PopupBin()
    await init_PopupWindow()
    await init_PowerButton()
    init_options4()
    init_jsx_runtime()
    Shutdown = ({ onClick }) => jsx2(PowerButton2, { label: "Shutdown", onClick: () => onClick("shutdown"), icon: "system-shutdown" })
    LogOut = ({ onClick }) => jsx2(PowerButton2, { label: "Log Out", onClick: () => onClick("logout"), icon: "system-log-out" })
    Reboot = ({ onClick }) => jsx2(PowerButton2, { label: "Reboot", onClick: () => onClick("reboot"), icon: "system-reboot" })
    Sleep = ({ onClick }) => jsx2(PowerButton2, { label: "Sleep", onClick: () => onClick("sleep"), icon: "weather-clear-night" })
    LineLayout = ({ onClick }) =>
      jsxs(Box2, { gap: "2xl", children: [jsx2(Shutdown, { onClick: onClick }), jsx2(LogOut, { onClick: onClick }), jsx2(Reboot, { onClick: onClick }), jsx2(Sleep, { onClick: onClick })] })
    BoxLayout = ({ onClick }) =>
      jsxs(Box2, {
        vertical: true,
        children: [
          jsxs(Box2, { gap: "2xl", children: [jsx2(Shutdown, { onClick: onClick }), jsx2(LogOut, { onClick: onClick })] }),
          jsxs(Box2, { gap: "2xl", children: [jsx2(Reboot, { onClick: onClick }), jsx2(Sleep, { onClick: onClick })] }),
        ],
      })
  },
})
function Verification({ label, onAccept }) {
  const hide2 = () => (app_default.get_window("verification").visible = false)
  return jsx2(PopupWindow, {
    shade: true,
    name: "verification",
    children: jsx2(PopupBin, {
      p: "2xl",
      r: "lg",
      children: jsxs(Box2, {
        vertical: true,
        gap: "2xl",
        m: "md",
        children: [
          jsxs(Box2, { vertical: true, m: "md", children: [jsx2("label", { className: "action", label: label() }), jsx2("label", { className: "confirm", label: "Are you sure?" })] }),
          jsxs(Box2, {
            gap: "xl",
            m: "lg",
            css: "min-width: 16rem",
            children: [
              jsx2(Button2, { hfill: true, onClicked: hide2, m: "md", children: jsx2(Box2, { hexpand: true, p: "xl", halign: CENTER, children: "No" }) }),
              jsx2(Button2, { hfill: true, onClicked: onAccept, m: "md", suggested: true, color: "error", children: jsx2(Box2, { hexpand: true, p: "xl", halign: CENTER, children: "Yes" }) }),
            ],
          }),
        ],
      }),
    }),
  })
}
var init_Verification = __esm({
  async "src/gtk3/src/powermenu/Verification.tsx"() {
    init_Box()
    await init_PopupWindow()
    init_PopupBin()
    init_Button()
    await init_app2()
    init_theme()
    init_jsx_runtime()
    void scss`PopupWindow#verification { label.action { font-size: 1.4em; font-weight: bold; color: $fg; } label.confirm { font-weight: normal; color: transparentize($fg, 0.1) }}`
  },
})
var powermenu_exports = {}
__export(powermenu_exports, { default: () => powermenu2 })
function powermenu2() {
  const label = Variable("")
  const selected = Variable("shutdown")
  const labels = { shutdown: "Shutdown", logout: "Log Out", reboot: "Reboot", sleep: "Sleep" }
  function onClick(btn) {
    label.set(labels[btn])
    selected.set(btn)
    verification.show()
    powermenu3.hide()
  }
  function onAccept() {
    exec(options_default4[selected.get()].get())
  }
  const verification = Verification({ label: label, onAccept: onAccept })
  const powermenu3 = PowerMenu3({ onClick: onClick })
  Object.assign(globalThis, { powermenu: onClick })
}
var init_powermenu2 = __esm({
  async "src/gtk3/src/powermenu/index.ts"() {
    await init_gjs()
    init_options4()
    await init_PowerMenu3()
    await init_Verification()
  },
})
var Progress_default
var init_Progress = __esm({
  async "src/gtk3/src/osd/Progress.tsx"() {
    init_theme()
    await init_Icon()
    init_jsx_runtime()
    void scss`box.Progress { box.fill { border-radius: $radius; background-color: $primary; transition: 200ms; icon { color: $accent-fg; } }}`
    Progress_default = ({ height = 18, width = 180, vertical = false, value, icon: icon2 }) => {
      let fill
      const unsub = value.subscribe((value2) => {
        if (value2 < 0) return
        const axis = vertical ? "height" : "width"
        const axisv = vertical ? height : width
        const min = vertical ? width : height
        const preferred2 = (axisv - min) * value2 + min
        fill.css = `min-${axis}: ${preferred2}px;`
      })
      return jsx2("box", {
        onDestroy: unsub,
        className: "Progress",
        expand: false,
        css: `
            min-width: ${width}px;
            min-height: ${height}px;
        `,
        children: jsx2("box", {
          className: "fill",
          setup: (self) => (fill = self),
          hexpand: vertical,
          vexpand: !vertical,
          halign: vertical ? FILL : START,
          valign: vertical ? END : FILL,
          children: jsx2(Icon2, {
            expand: true,
            symbolic: true,
            valign: vertical ? START : FILL,
            halign: vertical ? FILL : END,
            icon: icon2,
            css: `
                    min-width: ${Math.min(width, height)}px;
                    min-height: ${Math.min(width, height)}px;
                    font-size: ${Math.min(width, height) * 0.65}px;
                `,
          }),
        }),
      })
    }
  },
})
var screenDevice, kbdDevice, screen, kbd, _kbdMax, _kbd, _screenMax, _screen, Brightness
var init_brightness = __esm({
  async "lib/core/service/brightness.ts"() {
    init_gobject()
    init_file()
    init_os()
    screenDevice = await bash`ls -w1 /sys/class/backlight | head -1`
    kbdDevice = await bash`ls -w1 /sys/class/leds | head -1`
    screen = `/sys/class/backlight/${screenDevice}`
    kbd = `/sys/class/leds/${kbdDevice}`
    Brightness = class extends GObject4.Object {
      constructor() {
        super()
        __privateAdd(this, _kbdMax, Number(readFile(`${kbd}/max_brightness`)))
        __privateAdd(this, _kbd, Number(readFile(`${kbd}/brightness`)))
        __privateAdd(this, _screenMax, Number(readFile(`${screen}/max_brightness`)))
        __privateAdd(this, _screen, Number(readFile(`${screen}/brightness`)) / __privateGet(this, _screenMax))
        monitorFile(`${screen}/brightness`, async (f) => {
          const v = await readFileAsync(f)
          __privateSet(this, _screen, Number(v) / __privateGet(this, _screenMax))
          this.notify("screen")
        })
        monitorFile(`${kbd}/brightness`, async (f) => {
          const v = await readFileAsync(f)
          __privateSet(this, _kbd, Number(v) / __privateGet(this, _kbdMax))
          this.notify("kbd")
        })
      }
      static get_default() {
        if (!this.instance) this.instance = new Brightness()
        return this.instance
      }
      get kbd() {
        return __privateGet(this, _kbd)
      }
      set kbd(value) {
        if (!dependencies("brightnessctl")) return
        if (value < 0 || value > __privateGet(this, _kbdMax)) return
        sh(`brightnessctl -d ${kbd} s ${value} -q`).then(() => {
          __privateSet(this, _kbd, value)
          this.notify("kbd")
        })
      }
      get screen() {
        return __privateGet(this, _screen)
      }
      set screen(percent) {
        if (!dependencies("brightnessctl")) return
        if (percent < 0) percent = 0
        if (percent > 1) percent = 1
        sh(`brightnessctl set ${Math.floor(percent * 100)}% -q`).then(() => {
          __privateSet(this, _screen, percent)
          this.notify("screen")
        })
      }
    }
    _kbdMax = new WeakMap()
    _kbd = new WeakMap()
    _screenMax = new WeakMap()
    _screen = new WeakMap()
    __publicField(Brightness, "instance")
    __decorateClass([property(Number)], Brightness.prototype, "kbd", 1)
    __decorateClass([property(Number)], Brightness.prototype, "screen", 1)
    Brightness = __decorateClass([register({ GTypeName: "Brightness" })], Brightness)
  },
})
var options_default5
var init_options5 = __esm({
  "src/gtk3/src/osd/options.ts"() {
    init_option()
    options_default5 = mkOptions("osd", { vertical: opt(true), timeout: opt(2e3), margin: opt(0), slide: opt(true), anchors: opt(["right"]) })
  },
})
import Wp4 from "gi://AstalWp"
function anchor(anchors) {
  return anchors.reduce((prev, a) => prev | Astal7.WindowAnchor[a.toUpperCase()], 0)
}
function OnScreenProgress({ vertical, visible }) {
  const brightness = Brightness.get_default()
  const speaker = Wp4.get_default().defaultSpeaker
  const iconName = variable_default("")
  const progValue = variable_default(0)
  const transitionType = variable_default.derive([options_default5.slide, options_default5.anchors], (s, a) => {
    if (!s) return CROSSFADE
    if (a.includes("top")) return SLIDE_DOWN
    if (a.includes("bottom")) return SLIDE_UP
    if (a.includes("left")) return SLIDE_RIGHT
    if (a.includes("right")) return SLIDE_LEFT
    return CROSSFADE
  })
  let count = 0
  function show(v, ico) {
    visible.set(true)
    progValue.set(v)
    iconName.set(ico)
    count++
    timeout(options_default5.timeout.get(), () => {
      count--
      if (count === 0) visible.set(false)
    })
  }
  return jsx2("revealer", {
    setup: (self) =>
      self
        .hook(brightness, "notify::screen", () => show(brightness.screen, icons.screen))
        .hook(brightness, "notify::kbd", () => show(brightness.kbd, icons.keyboard))
        .hook(speaker, "notify::volume", () => show(speaker.volume, speaker.volumeIcon)),
    revealChild: visible(),
    transitionType: transitionType(),
    children: jsx2("box", {
      css: options_default5.margin((m) => `margin: ${m}px`),
      children: jsx2(PopupBin, { children: jsx2(Progress_default, { value: progValue(), width: vertical ? 42 : 300, height: vertical ? 300 : 42, vertical: vertical, icon: iconName() }) }),
    }),
  })
}
function OSD(monitor) {
  const { vertical, anchors } = options_default5
  const visible = variable_default(false)
  return jsx2("window", {
    gdkmonitor: monitor,
    clickThrough: true,
    className: "OSD",
    namespace: "osd",
    application: app_default,
    layer: Astal7.Layer.OVERLAY,
    onButtonPressEvent: () => visible.set(false),
    anchor: anchors(anchor),
    children: vertical((vertical2) => OnScreenProgress({ vertical: vertical2, visible: visible })),
  })
}
var icons
var init_OSD = __esm({
  async "src/gtk3/src/osd/OSD.tsx"() {
    await init_gtk3()
    init_time()
    init_variable()
    init_PopupBin()
    await init_Progress()
    await init_brightness()
    init_options5()
    init_theme()
    init_jsx_runtime()
    icons = { indicator: "display-brightness", keyboard: "keyboard-brightness", screen: "display-brightness", speaker: "audio-speakers" }
    void scss`window.OSD .PopupBin { margin: $spacing * 2; padding: $padding * .4; @if ($radius > 0) { border-radius: $radius + ($padding * .4); }}`
  },
})
var osd_exports = {}
__export(osd_exports, { default: () => notifications2 })
function notifications2() {
  app_default.get_monitors().map(OSD)
}
var init_osd = __esm({
  async "src/gtk3/src/osd/index.ts"() {
    await init_gtk3()
    await init_OSD()
  },
})
var options_default6
var init_options6 = __esm({
  "src/gtk3/src/notifications/options.ts"() {
    init_option()
    options_default6 = mkOptions("notifications", { anchor: opt(["top", "right"]), blacklist: opt(["Spotify"]), width: opt(24), dissmissOnHover: opt(false) })
  },
})
import GLib10 from "gi://GLib"
import Astal9 from "gi://Astal?version=3.0"
function Notification2(props) {
  const { notification: n, onHoverLost } = props
  const showActions = variable_default(false)
  return jsx2("eventbox", {
    onHover: () => showActions.set(true),
    onHoverLost: () => {
      onHoverLost?.()
      showActions.set(false)
    },
    children: jsxs(Box2, {
      vertical: true,
      className: "Notification",
      children: [
        jsxs(Box2, {
          className: "app",
          gap: "sm",
          p: "md",
          pl: "lg",
          children: [
            (n.appIcon || n.desktopEntry) && jsx2(Icon2, { symbolic: true, className: "icon", css: "font-size: 1rem", icon: n.appIcon || n.desktopEntry }),
            jsx2("label", { className: "name", halign: START, truncate: true, label: n.appName }),
            jsx2("label", { className: "time", hexpand: true, halign: END, label: time2(n.time) }),
            jsx2("box", {
              children: jsx2(Button2, { onClicked: () => n.dismiss(), color: "error", flat: true, children: jsx2(Box2, { m: "sm", children: jsx2(Icon2, { symbolic: true, icon: "window-close" }) }) }),
            }),
          ],
        }),
        jsx2(Separator, { mx: "sm" }),
        jsxs(Box2, {
          gap: "xl",
          p: "lg",
          className: "body",
          children: [
            n.image && GLib10.file_test(n.image, GLib10.FileTest.EXISTS) && jsx2("box", { valign: START, className: "image", css: `background-image: url('${n.image}')` }),
            n.image &&
              Astal9.Icon.lookup_icon(n.image) &&
              jsx2("box", { expand: false, valign: START, className: "icon-image", children: jsx2("icon", { icon: n.image, expand: true, halign: CENTER, valign: CENTER }) }),
            jsxs(Box2, {
              vertical: true,
              children: [
                jsx2("label", { className: "title", halign: START, xalign: 0, label: n.summary, truncate: true }),
                n.body && jsx2("label", { wrap: true, useMarkup: true, halign: START, xalign: 0, justifyFill: true, label: n.body }),
              ],
            }),
          ],
        }),
        n.get_actions().length > 0 &&
          jsx2("revealer", {
            transitionType: SLIDE_DOWN,
            revealChild: showActions(),
            children: jsx2(Box2, {
              gap: "xl",
              m: "md",
              children: n.get_actions().map(({ label, id }) =>
                jsx2(Button2, {
                  suggested: true,
                  color: "primary",
                  hexpand: true,
                  hfill: true,
                  onClicked: () => n.invoke(id),
                  children: jsx2(Box2, { my: "md", children: jsx2("label", { label: label, halign: CENTER, hexpand: true }) }),
                })
              ),
            }),
          }),
      ],
    }),
  })
}
var time2
var init_Notification2 = __esm({
  async "src/gtk3/src/notifications/Notification.tsx"() {
    init_Button()
    init_Box()
    await init_Separator()
    await init_Icon()
    init_variable()
    init_theme()
    init_jsx_runtime()
    void scss`.Notifications box.Notification { color: $fg; box.app { .name, .icon, .time { color: transparentize($fg, .4); } } box.body { box.image, box.icon-image { min-height: 5rem; min-width: 5rem; } box.image { border-radius: $radius; background-size: cover; background-position: center; @if $shadows { box-shadow: $box-shadow; } } box.icon-image icon { font-size: 4.8em; @if $shadows { -gtk-icon-shadow: $text-shadow; } } .title { font-weight: bold; font-size: 1.14rem; } }}`
    time2 = (time3, format2 = "%H:%M") => GLib10.DateTime.new_from_unix_local(time3).format(format2)
  },
})
import Notifd7 from "gi://AstalNotifd"
function Animated(n) {
  const notifd = Notifd7.get_default()
  const transition = 200
  let resolved = false
  let box
  let revealer
  idle(() => (revealer.reveal_child = true))
  function onResolved() {
    if (resolved) return
    resolved = true
    revealer.reveal_child = false
    timeout(transition, () => {
      box.destroy()
    })
  }
  return jsx2("box", {
    halign: END,
    setup: (self) => {
      box = self
      self.hook(n, "resolved", onResolved)
      self.hook(n, "dismissed", () => {
        if (options_default6.dissmissOnHover.get()) onResolved()
      })
      self.hook(notifd, "notified", (_, id, replaced) => {
        void (replaced && id == n.id && self.destroy())
      })
    },
    children: jsx2("revealer", {
      transitionDuration: transition,
      transitionType: SLIDE_DOWN,
      setup: (self) => (revealer = self),
      children: jsx2(PopupBin, {
        p: "lg",
        r: "md",
        css: options_default6.width((w) => `min-width: ${w}rem`),
        children: jsx2(Box2, { m: "md", children: jsx2(Notification2, { onHoverLost: onResolved, notification: n }) }),
      }),
    }),
  })
}
function Notifications(monitor) {
  const notifd = Notifd7.get_default()
  const blacklist = options_default6.blacklist.get
  const anchor2 = options_default6.anchor((anchors) => anchors.map((a) => Astal7.WindowAnchor[a.toUpperCase()]).reduce((prev, a) => prev | a, 0))
  function setup(self) {
    self.hook(notifd, "notified", (_, id) => {
      const n = notifd.get_notification(id)
      if (blacklist().includes(n.appName)) return
      self.set_children([Animated(n), ...self.get_children()])
    })
  }
  return jsx2("window", {
    className: "Notifications",
    name: `notifications-${monitor.model}`,
    namespace: "notifications",
    application: app_default,
    anchor: anchor2,
    gdkmonitor: monitor,
    css: "background-color: transparent",
    children: jsx2("box", { vertical: true, setup: setup }),
  })
}
var init_Notifications2 = __esm({
  async "src/gtk3/src/notifications/Notifications.tsx"() {
    await init_gtk3()
    init_time()
    init_options6()
    init_PopupBin()
    init_Box()
    await init_Notification2()
    init_jsx_runtime()
  },
})
var notifications_exports = {}
__export(notifications_exports, { default: () => notifications3 })
function notifications3() {
  app_default.get_monitors().map(Notifications)
  if (options_default.hyprland.enable.get()) {
    import("gi://AstalHyprland").then((m) => {
      const h = m.default.get_default()
      h.message_async("keyword layerrule noanim,notifications", null)
    })
  }
}
var init_notifications2 = __esm({
  async "src/gtk3/src/notifications/index.ts"() {
    init_options()
    await init_Notifications2()
    await init_gtk3()
  },
})
var Grid
var init_Grid = __esm({
  async "lib/gtk3/src/primitive/Grid.tsx"() {
    await init_gtk3()
    init_gobject()
    Grid = class extends astalify(Gtk5.Grid) {
      get vertical() {
        return this.orientation == Gtk5.Orientation.VERTICAL
      }
      set vertical(v) {
        this.orientation = Gtk5.Orientation[v ? "VERTICAL" : "HORIZONTAL"]
      }
      add(child) {
        const { length } = this.get_children()
        const x = length % this.breakpoint
        const y = Math.floor(length / this.breakpoint)
        const row = this.vertical ? y : x
        const col = this.vertical ? x : y
        this.attach(child, row, col, 1, 1)
      }
      reset_children(children = this.get_children()) {
        for (const ch of children) {
          this.remove(ch)
        }
        for (const ch of children) this.add(ch)
      }
      constructor({ breakpoint = 5, ...props }) {
        super({ breakpoint: breakpoint, ...props })
        this.connect("notify::breakpoint", this.reset_children.bind(this))
        this.reset_children()
      }
    }
    __decorateClass([property(Number)], Grid.prototype, "breakpoint", 2)
    __decorateClass([property(Boolean)], Grid.prototype, "vertical", 1)
    Grid = __decorateClass([register({ GTypeName: "Fixed" })], Grid)
  },
})
function AppButton2({ app }) {
  return jsx2(Button2, {
    flat: true,
    r: "2xl",
    m: "2xl",
    tooltipText: app.description,
    onClicked: () => {
      app.launch()
      app_default.get_window("drawer").visible = false
    },
    children: jsxs(Box2, {
      vertical: true,
      p: "lg",
      children: [jsx2(Box2, { mx: "2xl", children: jsx2(Icon2, { icon: app.iconName, size: 5 }) }), jsx2("label", { truncate: true, label: app.name })],
    }),
  })
}
var init_AppButton2 = __esm({
  async "src/gtk3/src/drawer/AppButton.tsx"() {
    await init_gtk3()
    init_Box()
    init_Button()
    await init_Icon()
    init_jsx_runtime()
  },
})
var options_default7
var init_options7 = __esm({
  "src/gtk3/src/drawer/options.ts"() {
    init_option()
    options_default7 = mkOptions("drawer", { rowSize: opt(11), rows: opt(6), solidBackground: opt(false), icon: { size: opt(3), monochrome: opt(false) } })
  },
})
import Apps3 from "gi://AstalApps"
function Drawer() {
  const apps = bind(new Apps3.Apps(), "list")
  const rows = options_default7.rows()
  const size2 = options_default7.rowSize()
  const solid = options_default7.solidBackground()
  const grids = Variable.derive([apps, rows, size2], (apps2, rows2, size3) => chunks(size3 * rows2, apps2))
  const visible = Variable(0)
  return jsx2(PopupWindow, {
    shade: true,
    name: "drawer",
    className: solid.as((s) => (s ? "solid" : "")),
    children: jsxs("box", {
      vertical: true,
      children: [
        jsx2("stack", {
          shown: visible(String),
          transitionType: Gtk5.StackTransitionType.SLIDE_LEFT_RIGHT,
          children: grids((grids2) => grids2.map((grid, i) => jsx2(Grid, { name: String(i), breakpoint: size2, children: grid.map((app) => jsx2(AppButton2, { app: app })) }))),
        }),
        jsx2(Box2, {
          hexpand: true,
          children: jsx2(Box2, {
            className: "Pager",
            halign: CENTER,
            hexpand: true,
            children: grids((grids2) =>
              grids2.length == 1
                ? []
                : grids2.map((_, i) =>
                    jsx2(Button2, {
                      flat: true,
                      m: "md",
                      className: visible((v) => (v == i ? "selected" : "")),
                      onClicked: () => visible.set(i),
                      children: jsx2(Box2, { m: "xl", halign: CENTER, valign: CENTER, children: String(i) }),
                    })
                  )
            ),
          }),
        }),
      ],
    }),
  })
}
var init_Drawer = __esm({
  async "src/gtk3/src/drawer/Drawer.tsx"() {
    await init_gtk3()
    await init_gjs()
    await init_PopupWindow()
    await init_Grid()
    init_Button()
    init_Box()
    await init_AppButton2()
    init_options7()
    init_array()
    init_theme()
    init_jsx_runtime()
    void scss`window#drawer { &.solid { background-color: $bg; } .Pager .Button { min-width: 2rem; min-width: 2rem; label { font-size: 0px; } .Box { transition: $transition; border-radius: $radius; background-color: $fg; min-width: .4rem; min-height: .4rem; } &.selected .Box { min-width: .6rem; min-height: .6rem; background-color: $primary; } }}`
  },
})
var drawer_exports = {}
__export(drawer_exports, { default: () => Drawer })
var init_drawer = __esm({
  async "src/gtk3/src/drawer/index.ts"() {
    await init_Drawer()
  },
})
import GLib11 from "gi://GLib?version=2.0"
import Gio7 from "gi://Gio?version=2.0"
function Info() {
  let win
  const wiki = "https://marble-shell.pages.dev/"
  const github = false ? "https://github.com/marble-shell/shell/issues/new" : "https://github.com/Aylur/dotfiles/issues/new"
  function shouldShow() {
    return !GLib11.file_test(`${CACHE}/info`, GLib11.FileTest.EXISTS)
  }
  function dontShow() {
    mkdir(CACHE)
    writeFile(`${CACHE}/info`, "O1G")
    win.hide()
  }
  function open(link) {
    return function () {
      Gio7.AppInfo.launch_default_for_uri_async(link, null, null, null)
      win.hide()
    }
  }
  function copy() {
    Gtk5.Clipboard.get_default(Gdk.Display.get_default()).set_text("0.1.1", -1)
    if (dependencies("notify-send")) {
      execAsync(["notify-send", "-a", "Marble", "-i", "edit-copy-symbolic", `Copied ${false ? "revision" : "version"} to clipboard`, "0.1.1"])
    }
  }
  return jsx2(PopupWindow, {
    setup: (self) => (win = self),
    visible: shouldShow(),
    name: "info",
    children: jsx2(PopupBin, {
      r: "xl",
      p: "2xl",
      children: jsxs(Box2, {
        vertical: true,
        p: "md",
        children: [
          jsx2("box", { halign: CENTER, className: "Logo" }),
          jsx2("label", { className: "program-name", label: "Marble Shell" }),
          jsx2("label", { className: "author", label: "Aylur" }),
          jsx2(Button2, { my: "sm", color: "primary", suggested: true, onClicked: copy, children: jsx2(Box2, { p: "lg", children: jsx2("label", { label: "0.1.1" }) }) }),
          jsx2(Box2, { my: "lg" }),
          jsx2(Button2, {
            hfill: true,
            m: "sm",
            tooltipText: wiki,
            onClicked: open(wiki),
            children: jsxs(Box2, { p: "lg", children: [jsx2("label", { hexpand: true, xalign: 0, label: "Browse Wiki" }), jsx2(Icon2, { symbolic: true, icon: "external-link" })] }),
          }),
          jsx2(Button2, {
            hfill: true,
            m: "sm",
            tooltipText: github,
            onClicked: open(github),
            children: jsxs(Box2, { p: "lg", children: [jsx2("label", { hexpand: true, xalign: 0, label: "Report an issue" }), jsx2(Icon2, { symbolic: true, icon: "external-link" })] }),
          }),
          jsx2(Button2, {
            suggested: true,
            color: "error",
            hfill: true,
            m: "sm",
            onClicked: dontShow,
            children: jsxs(Box2, { p: "lg", children: [jsx2("label", { hexpand: true, xalign: 0, label: "Don't Show Again" }), jsx2(Icon2, { symbolic: true, icon: "window-close" })] }),
          }),
        ],
      }),
    }),
  })
}
var init_Info = __esm({
  async "src/gtk3/src/info/Info.tsx"() {
    await init_PopupWindow()
    init_Box()
    await init_Icon()
    init_PopupBin()
    init_Button()
    init_theme()
    init_os()
    init_file()
    await init_gtk3()
    await init_gjs()
    init_jsx_runtime()
    void scss`window#info { .PopupBin { min-width: 14rem; } .Logo { min-width: 8rem; min-height: 8rem; border-radius: 99rem; background-size: cover; background-position: center; margin: $spacing 0; background-image: url('http://marble-shell.pages.dev/logo.png') } .program-name { font-size: 1.1em; font-weight: bold; } .author { color: transparentize($fg, 0.5); }}`
  },
})
var info_exports = {}
__export(info_exports, { default: () => Info })
var init_info = __esm({
  async "src/gtk3/src/info/index.ts"() {
    await init_Info()
  },
})
import Gio from "gi://Gio?version=2.0"
import GLib from "gi://GLib?version=2.0"
var version_default = "0.1.1\n"
try {
  Object.assign(globalThis, { DEV: false })
} catch (err) {
  if (err instanceof ReferenceError) {
    Object.assign(globalThis, { DEV: true })
  }
}
try {
  Object.assign(globalThis, { VERSION: "0.1.1" })
} catch (err) {
  if (err instanceof ReferenceError) {
    Object.assign(globalThis, { VERSION: version_default.trim() })
  }
}
async function Gtk(gtk) {
  try {
    if (gtk == 3) {
      return await import("gi://Gtk?version=3.0").then((m) => m.default)
    }
    if (gtk == 4) {
      return await import("gi://Gtk?version=4.0").then((m) => m.default)
    }
  } catch (error) {
    logError(error)
  }
  throw new Error(`invalid Gtk version ${gtk}`)
}
async function init(gtk) {
  const { Align, RevealerTransitionType } = await Gtk(gtk)
  Object.assign(globalThis, {
    START: Align.START,
    CENTER: Align.CENTER,
    END: Align.END,
    FILL: Align.FILL,
    SLIDE_UP: RevealerTransitionType.SLIDE_UP,
    SLIDE_DOWN: RevealerTransitionType.SLIDE_DOWN,
    SLIDE_LEFT: RevealerTransitionType.SLIDE_LEFT,
    SLIDE_RIGHT: RevealerTransitionType.SLIDE_RIGHT,
    CROSSFADE: RevealerTransitionType.CROSSFADE,
    CACHE: `${GLib.get_user_cache_dir()}/marble`,
    CONFIG: GLib.getenv("MARBLE_CONFIG") || `${GLib.get_user_config_dir()}/marble`,
    TMP: `${GLib.get_user_runtime_dir()}/marble`,
    USER: GLib.get_user_name(),
    HOME: GLib.get_home_dir(),
  })
  for (const dir of [TMP, CACHE, CONFIG]) {
    if (!GLib.file_test(dir, GLib.FileTest.IS_DIR)) Gio.File.new_for_path(dir).make_directory(null)
  }
}
await init(3)
await init_app2()
await init_gtk3()
init_theme()
function theme2() {
  return theme({ App: app_default, Astal: Astal7 })
}
void scss`@mixin margin($m: $spacing) { &.m-sm { margin: $m * .2; } &.m-md { margin: $m * .4; } &.m-lg { margin: $m * .6; } &.m-xl { margin: $m * .8; } &.m-2xl { margin: $m; } &.mx-sm { margin-right: ($m * .2); margin-left: ($m * .2); } &.mx-md { margin-right: ($m * .4); margin-left: ($m * .4); } &.mx-lg { margin-right: ($m * .6); margin-left: ($m * .6); } &.mx-xl { margin-right: ($m * .8); margin-left: ($m * .8); } &.mx-2xl { margin-right: $m; margin-left: $m } &.my-sm { margin-top: ($m * .2); margin-bottom: ($m * .2); } &.my-md { margin-top: ($m * .4); margin-bottom: ($m * .4); } &.my-lg { margin-top: ($m * .6); margin-bottom: ($m * .6); } &.my-xl { margin-top: ($m * .8); margin-bottom: ($m * .8); } &.my-2xl { margin-top: $m; margin-bottom: $m; } &.mt-sm { margin-top: ($m * .2); } &.mt-md { margin-top: ($m * .4); } &.mt-lg { margin-top: ($m * .6); } &.mt-xl { margin-top: ($m * .8); } &.mt-2xl { margin-top: $m; } &.mb-sm { margin-bottom: ($m * .2); } &.mb-md { margin-bottom: ($m * .4); } &.mb-lg { margin-bottom: ($m * .6); } &.mb-xl { margin-bottom: ($m * .8); } &.mb-2xl { margin-bottom: $m; } &.mr-sm { margin-right: ($m * .2); } &.mr-md { margin-right: ($m * .4); } &.mr-lg { margin-right: ($m * .6); } &.mr-xl { margin-right: ($m * .8); } &.mr-2xl { margin-right: $m; } &.ml-sm { margin-left: ($m * .2); } &.ml-md { margin-left: ($m * .4); } &.ml-lg { margin-left: ($m * .6); } &.ml-xl { margin-left: ($m * .8); } &.ml-2xl { margin-left: $m; }}@mixin padding($p: $padding) { &.p-sm { padding: $p * .2; } &.p-md { padding: $p * .4; } &.p-lg { padding: $p * .6; } &.p-xl { padding: $p * .8; } &.p-2xl { padding: $p; } &.px-sm { padding-right: ($p * .2); padding-left: ($p * .2); } &.px-md { padding-right: ($p * .4); padding-left: ($p * .4); } &.px-lg { padding-right: ($p * .6); padding-left: ($p * .6); } &.px-xl { padding-right: ($p * .8); padding-left: ($p * .8); } &.px-2xl { padding-right: $p; padding-left: $p; } &.py-sm { padding-top: ($p * .2); padding-bottom: ($p * .2); } &.py-md { padding-top: ($p * .4); padding-bottom: ($p * .4); } &.py-lg { padding-top: ($p * .6); padding-bottom: ($p * .6); } &.py-xl { padding-top: ($p * .8); padding-bottom: ($p * .8); } &.py-2xl { padding-top: $p; padding-bottom: $p; } &.pt-sm { padding-top: ($p * .2); } &.pt-md { padding-top: ($p * .4); } &.pt-lg { padding-top: ($p * .6); } &.pt-xl { padding-top: ($p * .8); } &.pt-2xl { padding-top: $p; } &.pb-sm { padding-bottom: ($p * .2); } &.pb-md { padding-bottom: ($p * .4); } &.pb-lg { padding-bottom: ($p * .6); } &.pb-xl { padding-bottom: ($p * .8); } &.pb-2xl { padding-bottom: $p; } &.pr-sm { padding-right: ($p * .2); } &.pr-md { padding-right: ($p * .4); } &.pr-lg { padding-right: ($p * .6); } &.pr-xl { padding-right: ($p * .8); } &.pr-2xl { padding-right: $p; } &.pl-sm { padding-left: ($p * .2); } &.pl-md { padding-left: ($p * .4); } &.pl-lg { padding-left: ($p * .6); } &.pl-xl { padding-left: ($p * .8); } &.pl-2xl { padding-left: $p; }}@mixin radius($r: $radius) { &.r-sm { border-radius: $r * .3; } &.r-md { border-radius: $r * .6; } &.r-lg { border-radius: $r * .9; } &.r-xl { border-radius: $r * 1.2; } &.r-2xl { border-radius: $r * 1.5; }}`
void scss`window.popup { >* { border: none; box-shadow: none; } menu { border-radius: $radius; background-color: $bg; padding: $padding; border: $border-width solid color.mix($fg, $border-color, .4%); separator { background-color: $border-color; } menuitem { all: unset; padding: $padding; transition: $transition; color: $fg; &:hover, &:focus { color: $primary; } &:first-child { margin-top: 0; } &:last-child { margin-bottom: 0; } } }}tooltip { * { all: unset; } background-color: transparent; border: none; >*>* { background-color: $bg; border-radius: $radius; border: $border-width solid color.mix($fg, $border-color, .4%); color: $fg; padding: 8px; margin: 4px; box-shadow: 0 0 3px 0 $shadow-color; }}`
init_options()
import GLib5 from "gi://GLib?version=2.0"
var help = (instanceName) => `
Usage:
    astal -i ${instanceName} [COMMAND] [ARGUMENTS]

Commands:
    version                 Print version
    inspect                 Open GTK debugger tool
    quit                    Quit the application
    eval [code]             Evaluate JavaScript
    toggle [name]           Toggle layer shell
`
async function getGtk(gtk) {
  switch (gtk) {
    case 3:
      return await import("gi://Gtk?version=3.0").then((m) => m.default)
    case 4:
      return await import("gi://Gtk?version=4.0").then((m) => m.default)
    default:
      throw Error("invalid gtk version")
  }
}
function run(...modules) {
  return async function () {
    for await (const app of modules) {
      try {
        app.default()
      } catch (error) {
        logError(error)
      }
    }
  }
}
async function start(props) {
  const { name, gtk, App, theme: theme3, callback: main2 } = props
  const instanceName = GLib5.getenv("INSTANCE_NAME") || name
  const Gtk7 = await getGtk(gtk)
  App.start({
    instanceName: instanceName,
    gtkTheme: "Adwaita",
    requestHandler(request, res) {
      const [cmd, ...args] = request.split(/\s+/)
      switch (cmd) {
        case "version":
          return res("0.1.1")
        case "help":
          return res(help(instanceName))
        case "inspect":
          return res(App.inspector())
        case "quit":
          return res(App.quit())
        case "toggle": {
          const name2 = args[0] || App.instanceName || ""
          const win = App.get_window(name2)
          if (win) {
            win.visible = !win.visible
            return res("ok")
          }
          return res(`${name2} layer does not exists`)
        }
        case "eval":
        default:
          return App.eval(args.join(" ")).then(res).catch(res)
      }
    },
    client(message, ...args) {
      print(message(args.join(" ")))
    },
    async main(...args) {
      if (["help", "--help", "-h"].some((cmd) => args.includes(cmd))) {
        print(help(instanceName))
        return App.quit(0)
      }
      if (["version", "--version", "-v"].some((cmd) => args.includes(cmd))) {
        print("0.1.1")
        return App.quit(0)
      }
      const settings = Gtk7.Settings.get_default()
      settings.gtkFontName = options_default.font.get()
      options_default.font.subscribe((v) => (settings.gtkFontName = v))
      try {
        await theme3()
        await main2()
      } catch (error) {
        logError(error)
        App.quit(1)
      }
    },
  })
}
function main(name, callback) {
  return start({ name: name, gtk: 3, App: app_default, theme: theme2, callback: callback })
}
main(
  "astal",
  run(
    init_launcher().then(() => launcher_exports),
    init_bar().then(() => bar_exports),
    init_powermenu2().then(() => powermenu_exports),
    init_osd().then(() => osd_exports),
    init_notifications2().then(() => notifications_exports),
    init_drawer().then(() => drawer_exports),
    init_info().then(() => info_exports)
  )
)
