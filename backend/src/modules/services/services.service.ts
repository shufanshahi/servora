import type { Config } from '../../config';
import { notFound } from '../../http/errors';
import type { PageMeta } from '../../http/response';
import type { ServiceRecord, ServicesRepository } from './services.repository';
import type { ListServicesFilters } from './services.schemas';

/** The service shape clients receive. */
export interface PublicService {
  id: string;
  name: string;
  description: string;
  /** Decimal amount, for example 65 or 49.99. */
  price: number;
  durationMinutes: number;
  category: string;
  /** Absolute URL, or null when the service has no image. */
  imageUrl: string | null;
  isFeatured: boolean;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export class ServicesService {
  private readonly baseUrl: string;

  constructor(
    config: Pick<Config, 'PUBLIC_BASE_URL'>,
    private readonly repository: ServicesRepository,
  ) {
    this.baseUrl = config.PUBLIC_BASE_URL.replace(/\/+$/, '');
  }

  async list(filters: ListServicesFilters): Promise<{ items: PublicService[]; meta: PageMeta }> {
    const { items, total } = await this.repository.list(filters);
    return {
      items: items.map((item) => this.toPublic(item)),
      meta: { page: filters.page, limit: filters.limit, total },
    };
  }

  async get(id: string): Promise<PublicService> {
    // A malformed id can never match a row, so answer 404 without asking the database
    // (which would otherwise raise an invalid-uuid error and become a 500).
    if (!UUID.test(id)) throw notFound('Service not found');
    const record = await this.repository.findActiveById(id);
    if (!record) throw notFound('Service not found');
    return this.toPublic(record);
  }

  private toPublic(record: ServiceRecord): PublicService {
    return {
      id: record.id,
      name: record.name,
      description: record.description,
      price: Number((record.priceCents / 100).toFixed(2)),
      durationMinutes: record.durationMinutes,
      category: record.category,
      imageUrl: record.imagePath ? `${this.baseUrl}${record.imagePath}` : null,
      isFeatured: record.isFeatured,
    };
  }
}
