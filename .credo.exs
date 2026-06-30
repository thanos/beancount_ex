%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: [~r/_build/, ~r/deps/, ~r/priv/,] # ~r/lib\/beancount\/parser\//]
      },
      strict: true
    }
  ]
}
