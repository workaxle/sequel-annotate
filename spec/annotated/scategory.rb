class SCategory < Sequel::Model(SDB[:categories])
end

# Table: categories
# Columns:
#  id   | integer      | PRIMARY KEY AUTOINCREMENT
#  name | varchar(255) | NOT NULL
