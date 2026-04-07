ts\nimport { IsUrl, IsOptional, IsUUID } from 'class-validator';\n\nexport class CreateVideoDto {\n @IsUrl()\n sourceUrl: string;\n\n @IsUUID()\n @IsOptional()\n templateId?: string;\n}\n
