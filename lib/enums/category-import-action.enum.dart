enum CategoryImportAction {
  /// Substitui a categoria existente e todos os seus produtos.
  overwrite,

  /// Cria uma nova categoria com um nome ligeiramente modificado (ex: "Bebidas (Cópia)").
  createNew,

  /// Cancela todo o processo de importação.
  cancel,
}