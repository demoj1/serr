Path.join(["rel", "plugins", "*.exs"])
|> Path.wildcard()
|> Enum.map(&Code.eval_file(&1))

use Mix.Releases.Config,
  default_release: :default,
  default_environment: Mix.env()

environment :dev do
  set(dev_mode: true)
  set(include_erts: false)
  set(cookie: :":p(qbfPEQC2&IBo3[w33p}71G`e^7`k2T5(XvgN1GE?`XKeo>mEv49bgm_:6CU{F")
end

environment :prod do
  set(include_erts: true)
  set(include_src: false)
  set(cookie: :".XKl=5dDMfv{h)1IAKpnX@=4m=_Az)F&u[zC8Jd{zJ5S>pZ(m)Vn$>H]r34X]moI")
end

release :serr do
  set(version: "0.1.0")

  set(
    applications: [
      :runtime_tools,
      :serr_logs,
      :serr_lint
    ]
  )
end
