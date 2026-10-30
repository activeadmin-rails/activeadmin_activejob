# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # For resources whose scoped_collection is a plain Array (e.g. queues and
    # workers, which backends return in full).
    module ArrayCollection
      protected

      def apply_pagination(chain)
        Kaminari.paginate_array(chain).page(params[Kaminari.config.param_name]).per(per_page)
      end
    end
  end
end
