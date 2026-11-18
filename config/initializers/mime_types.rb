# Export Excel (grille des tarifs) : Rails ne connaît pas le type xlsx par défaut.
Mime::Type.register "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", :xlsx
