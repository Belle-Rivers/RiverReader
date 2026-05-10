from pydantic import BaseModel, Field


class VersionResponse(BaseModel):
    version: str = Field(description="API package version", examples=["0.1.0"])
    api: str = Field(description="Stable API prefix", examples=["v1"])
