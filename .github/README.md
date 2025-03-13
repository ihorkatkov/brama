# GitHub CI Pipeline

This directory contains GitHub Actions workflows for continuous integration.

## CI Pipeline Setup

The `ci.yml` workflow is configured to run on push to any branch and includes:

1. Building and testing the Elixir application
2. Running code quality checks (Credo, Sobelow)

## Required Dependencies

To run these checks locally, add the following to your `mix.exs` file:

```elixir
# In the deps function:
defp deps do
  [
    # ... existing deps
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Running Checks Locally

```bash
# Run tests
mix test

# Run Credo
mix credo --strict

# Run Sobelow
mix sobelow --config
```

The CI pipeline will automatically run these checks on every push. 