import {
  Controller,
  Get,
  Injectable,
  Module,
  NotFoundException,
} from '@nestjs/common';
import { ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { InjectRepository, TypeOrmModule } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Public } from '../common/decorators/auth.decorators.js';
import { Category } from './category.entity.js';

export const DEFAULT_CATEGORIES: Array<
  Pick<Category, 'name' | 'slug' | 'icon' | 'description' | 'sortOrder'>
> = [
  {
    name: 'Gas',
    slug: 'gas',
    icon: 'gas',
    description: 'Cylinder delivery, refills and gas line installation',
    sortOrder: 1,
  },
  {
    name: 'Water',
    slug: 'water',
    icon: 'water',
    description: 'Drinking water delivery, tanks and filtration',
    sortOrder: 2,
  },
  {
    name: 'Electricity',
    slug: 'electricity',
    icon: 'electricity',
    description: 'Generator subscriptions, wiring and repairs',
    sortOrder: 3,
  },
  {
    name: 'Internet & Wi-Fi',
    slug: 'internet',
    icon: 'wifi',
    description: 'Home internet plans, routers and installation',
    sortOrder: 4,
  },
  {
    name: 'Satellite & TV',
    slug: 'satellite',
    icon: 'satellite',
    description: 'Dish installation, receivers and channel packages',
    sortOrder: 5,
  },
  {
    name: 'Solar Energy',
    slug: 'solar',
    icon: 'solar',
    description: 'Solar panels, batteries and inverter maintenance',
    sortOrder: 6,
  },
  {
    name: 'Plumbing',
    slug: 'plumbing',
    icon: 'plumbing',
    description: 'Leaks, pipes, heaters and pumps',
    sortOrder: 7,
  },
  {
    name: 'Home Maintenance',
    slug: 'maintenance',
    icon: 'maintenance',
    description: 'Handyman, AC and appliance repair',
    sortOrder: 8,
  },
];

@Injectable()
export class CategoriesService {
  constructor(
    @InjectRepository(Category)
    private readonly categories: Repository<Category>,
  ) {}

  findAll(): Promise<Category[]> {
    return this.categories.find({ order: { sortOrder: 'ASC', name: 'ASC' } });
  }

  async findById(id: string): Promise<Category> {
    const category = await this.categories.findOneBy({ id });
    if (!category) throw new NotFoundException('Category not found');
    return category;
  }

  /** Inserts any missing default categories (idempotent). */
  async ensureDefaults(): Promise<void> {
    for (const def of DEFAULT_CATEGORIES) {
      if (!(await this.categories.existsBy({ slug: def.slug }))) {
        await this.categories.save(this.categories.create(def));
      }
    }
  }
}

@ApiTags('Categories')
@Controller('categories')
export class CategoriesController {
  constructor(private readonly categoriesService: CategoriesService) {}

  @Public()
  @Get()
  @ApiOkResponse({ type: [Category] })
  findAll() {
    return this.categoriesService.findAll();
  }
}

@Module({
  imports: [TypeOrmModule.forFeature([Category])],
  controllers: [CategoriesController],
  providers: [CategoriesService],
  exports: [CategoriesService],
})
export class CategoriesModule {}
