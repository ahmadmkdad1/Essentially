import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsEnum,
  IsIn,
  IsInt,
  IsLatitude,
  IsLongitude,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { PaginationQueryDto } from '../../common/dto/pagination.dto.js';
import { ListingStatus, PriceUnit } from '../../common/enums.js';
import { Listing } from '../listing.entity.js';

export class CreateListingDto {
  @ApiProperty({ example: 'Gas cylinder refill (10kg)' })
  @IsString()
  @MinLength(3)
  @MaxLength(120)
  title: string;

  @ApiProperty({ example: 'Same-day delivery and safe installation.' })
  @IsString()
  @MinLength(10)
  @MaxLength(2000)
  description: string;

  @ApiProperty({ example: 12.5 })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(1_000_000)
  price: number;

  @ApiPropertyOptional({ enum: PriceUnit, default: PriceUnit.FIXED })
  @IsOptional()
  @IsEnum(PriceUnit)
  priceUnit?: PriceUnit;

  @ApiPropertyOptional({ example: 'USD', default: 'USD' })
  @IsOptional()
  @IsString()
  @Length(3, 3)
  currency?: string;

  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  categoryId: string;

  @ApiProperty({ example: 33.8938 })
  @Type(() => Number)
  @IsLatitude()
  latitude: number;

  @ApiProperty({ example: 35.5018 })
  @Type(() => Number)
  @IsLongitude()
  longitude: number;

  @ApiProperty({ example: 'Hamra, Beirut' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  address: string;

  @ApiPropertyOptional({ default: 15, minimum: 1, maximum: 200 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  serviceRadiusKm?: number;
}

export class UpdateListingDto extends PartialType(CreateListingDto) {}

export class SetListingActiveDto {
  @ApiProperty({ enum: [ListingStatus.ACTIVE, ListingStatus.PAUSED] })
  @IsIn([ListingStatus.ACTIVE, ListingStatus.PAUSED])
  status: ListingStatus.ACTIVE | ListingStatus.PAUSED;
}

export enum ListingSort {
  DISTANCE = 'distance',
  PRICE_ASC = 'price_asc',
  PRICE_DESC = 'price_desc',
  RATING = 'rating',
  NEWEST = 'newest',
}

export class SearchListingsDto extends PaginationQueryDto {
  @ApiPropertyOptional({ description: 'Customer latitude', example: 33.8938 })
  @IsOptional()
  @Type(() => Number)
  @IsLatitude()
  lat?: number;

  @ApiPropertyOptional({ description: 'Customer longitude', example: 35.5018 })
  @IsOptional()
  @Type(() => Number)
  @IsLongitude()
  lng?: number;

  @ApiPropertyOptional({ default: 25, minimum: 1, maximum: 500 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(500)
  radiusKm: number = 25;

  @ApiPropertyOptional({ format: 'uuid' })
  @IsOptional()
  @IsUUID()
  categoryId?: string;

  @ApiPropertyOptional({ description: 'Free-text search on title/description' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  q?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  maxPrice?: number;

  @ApiPropertyOptional({ enum: ListingSort, default: ListingSort.DISTANCE })
  @IsOptional()
  @IsEnum(ListingSort)
  sort: ListingSort = ListingSort.DISTANCE;
}

export class ListingWithDistance extends Listing {
  @ApiPropertyOptional({ description: 'Distance from the customer (km)' })
  distanceKm?: number | null;

  @ApiPropertyOptional({
    description: "Whether the customer is inside the provider's service radius",
  })
  withinServiceArea?: boolean | null;
}
