import configparser
from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict


class PathSettings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
    CONFIG_FILE_PATH: str


_path_settings = PathSettings()

_config = configparser.ConfigParser()
_config.optionxform = str
_full_path = Path.home() / Path(_path_settings.CONFIG_FILE_PATH)
_config.read(_full_path)

_db_data = dict(_config["database"])
_app_data = dict(_config["service"])


class ServiceSettings(BaseSettings):
    model_config = SettingsConfigDict(case_sensitive=False)

    HOST: str
    PORT: int


class DatabaseSettings(BaseSettings):
    model_config = SettingsConfigDict(case_sensitive=False)

    DB_SCHEME: str
    DB_USER: str
    DB_PASSWORD: str
    DB_NAME: str
    DB_HOST: str
    DB_PORT: int

    @property
    def database_url(self) -> str:
        return (
            f"{self.DB_SCHEME}://{self.DB_USER}:{self.DB_PASSWORD}"
            f"@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"
        )


service_settings = ServiceSettings(**_app_data)
db_settings = DatabaseSettings(**_db_data)
