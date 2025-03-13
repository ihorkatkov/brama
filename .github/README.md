# GitHub CI Pipeline

This directory contains GitHub Actions workflows for continuous integration.

## CI Pipeline Setup

The repository contains the following workflow files:

### 1. ci.yml

The main CI workflow is configured to run on push to any branch and includes:

1. Building and testing the Elixir application
2. Running code quality checks (Credo, Sobelow)

### 2. dialyzer.yml

A separate workflow for static analysis using Dialyzer:

1. Performs type checking and finds potential bugs
2. Uses PLT caching for faster subsequent runs

## Required Dependencies

To run these checks locally, add the following to your `mix.exs` file:

```elixir
# In the project function:
def project do
  [
    # ... existing config
    dialyzer: [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_apps: [:ex_unit, :mix],
      plt_core_path: "priv/plts/"
    ]
  ]
end

# In the deps function:
defp deps do
  [
    # ... existing deps
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
    {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
  ]
end
```

Then run:

```bash
mix deps.get
mkdir -p priv/plts
```

## Running Checks Locally

```bash
# Run tests
mix test

# Run Credo
mix credo --strict

# Run Sobelow
mix sobelow --config

# Run Dialyzer
mix dialyzer
```

The CI pipelines will automatically run these checks on every push. 