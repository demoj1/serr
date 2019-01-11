use Mix.Config

config :nostrum,
  token: System.get_env("DISCORD_TOKEN")

config :logger, :console,
  handle_otp_reports: true,
  handle_sasl_reports: true,
  level: :debug,
  format: "$time [$level] $metadata\n└── $message\n\n",
  metadata: [:module, :function, :file, :line]

config :serr_logs, SerrLogs.Scheduler,
  global: true,
  jobs: [
    {"* * * * *", {SerrLogs.Doctor, :check_health, []}},
    {"* * * * *", {SerrLogs.Monitor.Build, :pool, []}}
  ]

config :serr_logs,
  spam_seconds: 60 * 60,
  observers: %{
    "dev" => %{
      pooling_minutes: 2,
      user: System.get_env("TEST_LOG_USER"),
      password: System.get_env("TEST_LOG_PASSWORD"),
      build_channel: 526_028_149_482_586_143,
      build_services: [
        "mercury",
        "egais",
        "ved-prices",
        "plugin-task-queue",
        "ved-prices"
      ],
      services: [
        %{
          service: "mercury",
          methods: nil,
          level: [1, 4],
          discord_channel: 524_225_026_577_268_752
        },
        %{
          service: "gis diagnostic ps",
          methods: nil,
          level: [1, 4],
          discord_channel: 524_225_079_530_225_664
        },
        %{
          service: "mercury diagnostics",
          methods: nil,
          level: [1, 4],
          discord_channel: 524_225_101_399_588_894
        },
        %{
          service: "mercury diagnostics ps",
          methods: nil,
          level: [1, 4],
          discord_channel: 526_989_204_253_835_264
        },
        %{
          service: "ved prices diagnostics ps",
          methods: nil,
          level: [1, 4],
          discord_channel: 524_225_126_401_703_937
        },
        %{
          service: "EGAIS",
          methods: nil,
          level: [1, 4],
          discord_channel: 524_225_151_253_086_248
        },
        %{
          service: "Сервис диагностики ограничения цен",
          methods: nil,
          level: [1, 4],
          discord_channel: 525_627_722_710_646_784
        }
      ]
    },
    "pre-test" => %{
      pooling_minutes: 2,
      user: System.get_env("TEST_LOG_USER"),
      password: System.get_env("TEST_LOG_PASSWORD"),
      build_channel: 526_028_176_422_469_632,
      build_services: [
        "mercury",
        "egais",
        "ved-prices",
        "plugin-task-queue",
        "ved-prices"
      ],
      services: [
        %{
          service: "mercury",
          methods: nil,
          level: [1, 4],
          discord_channel: 524_225_285_734_924_288
        },
        %{
          service: "gis diagnostic ps",
          methods: nil,
          level: [1, 4],
          discord_channel: 524_225_400_281_366_544
        },
        %{
          service: "mercury diagnostics",
          methods: nil,
          level: [1, 4],
          discord_channel: 524_225_425_506_041_866
        },
        %{
          service: "mercury diagnostics ps",
          methods: nil,
          level: [1, 4],
          discord_channel: 526_989_176_864_899_092
        },
        %{
          service: "ved prices diagnostics ps",
          methods: nil,
          level: [1, 4],
          discord_channel: 524_225_449_002_270_720
        },
        %{
          service: "EGAIS",
          methods: nil,
          level: [1, 4],
          discord_channel: 524_225_468_539_600_897
        },
        %{
          service: "Сервис диагностики ограничения цен",
          methods: nil,
          level: [1, 4],
          discord_channel: 525_627_703_022_452_746
        }
      ]
    },
    "test" => %{
      pooling_minutes: 2,
      user: System.get_env("TEST_LOG_USER"),
      password: System.get_env("TEST_LOG_PASSWORD"),
      build_channel: 526_028_195_657_547_777,
      build_services: [
        "mercury",
        "egais",
        "ved-prices",
        "plugin-task-queue",
        "ved-prices"
      ],
      services: [
        %{
          service: "mercury",
          methods: nil,
          level: [1, 4],
          discord_channel: 524_225_691_886_026_752
        },
        %{
          service: "gis diagnostic ps",
          methods: nil,
          level: [1, 4],
          discord_channel: 524_225_713_688_018_944
        },
        %{
          service: "mercury diagnostics",
          methods: nil,
          level: [1, 4],
          discord_channel: 524_225_763_411_755_009
        },
        %{
          service: "mercury diagnostics ps",
          methods: nil,
          level: [1, 4],
          discord_channel: 526_989_153_271_939_083
        },
        %{
          service: "ved prices diagnostics ps",
          methods: nil,
          level: [1, 4],
          discord_channel: 524_225_788_547_956_737
        },
        %{
          service: "EGAIS",
          methods: nil,
          level: [1, 4],
          discord_channel: 524_225_811_658_571_777
        },
        %{
          service: "Сервис диагностики ограничения цен",
          methods: nil,
          level: [1, 4],
          discord_channel: 525_627_679_668_699_137
        },
        %{
          service: nil,
          methods: [
            "WhDocsMercuryAPI.ProcessDocs",
            "WhDocsMercuryAPI.ProcessAnswer",
            "МеркурийВх_Events.СписокХраним",
            "МеркурийИсх.DocNomList",
            "МеркурийВх.DocNomList",
            "МеркурийВх.SendInMercury"
          ],
          level: [1, 4],
          discord_channel: 533_312_699_841_380_363
        }
      ]
    },
    "fix" => %{
      pooling_minutes: 2,
      user: System.get_env("TEST_LOG_USER"),
      password: System.get_env("TEST_LOG_PASSWORD"),
      build_channel: 526_028_105_777_807_370,
      build_services: [
        "mercury",
        "egais",
        "ved-prices",
        "plugin-task-queue",
        "ved-prices"
      ],
      services: [
        %{
          service: "mercury",
          methods: nil,
          level: [1, 4],
          discord_channel: 524_226_034_002_952_203
        },
        %{
          service: "gis diagnostic ps",
          methods: nil,
          level: [1, 4],
          discord_channel: 524_226_048_926_285_830
        },
        %{
          service: "mercury diagnostics",
          methods: nil,
          level: [1, 4],
          discord_channel: 524_226_067_414_908_928
        },
        %{
          service: "mercury diagnostics ps",
          methods: nil,
          level: [1, 4],
          discord_channel: 526_989_117_175_627_776
        },
        %{
          service: "ved prices diagnostics ps",
          methods: nil,
          level: [1, 4],
          discord_channel: 524_226_081_943_977_989
        },
        %{
          service: "EGAIS",
          methods: nil,
          level: [1, 4],
          discord_channel: 524_226_094_312_980_490
        },
        %{
          service: "Сервис диагностики ограничения цен",
          methods: nil,
          level: [1, 4],
          discord_channel: 525_627_626_329_604_096
        },
        %{
          service: nil,
          methods: [
            "WhDocsMercuryAPI.ProcessDocs",
            "WhDocsMercuryAPI.ProcessAnswer",
            "МеркурийВх_Events.СписокХраним",
            "МеркурийИсх.DocNomList",
            "МеркурийВх.DocNomList",
            "МеркурийВх.SendInMercury"
          ],
          level: [1, 4],
          discord_channel: 533_312_875_649_826_816
        }
      ]
    }
  }
