-- PostgreSQL nie usuwa wartosci z ENUM-a bez przebudowy typu, co na
-- dzialajacej bazie wymagaloby przepisania users.role. Wartosc zostaje;
-- jest nieszkodliwa, bo bez tabel Studia (000090) nie ma czego
-- autoryzowac, a AdminGuard i tak sprawdza role po nazwie.
SELECT 1;
