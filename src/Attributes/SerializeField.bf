using System;
using System.Collections;
using System.Reflection;

namespace Serialize
{
	struct SerializeFieldAttribute : Attribute, IOnFieldInit
	{
		public bool Serialize;

		public String Rename = null;

		public bool Optional
		{
			get => HasDefault || (_optional ?? false);
			set mut => _optional = value;
		}

		public String Default = null;
		public String DefaultValue = null;

		public String NumberFormat = null;

		public bool HasDefault => Default != null || DefaultValue != null;

		private Nullable<bool> _optional = null;

		public this(bool serialize = true)
		{
			Serialize = serialize;
		}

		[Comptime]
		public void OnFieldInit(FieldInfo fieldInfo, Self* prev)
		{
			let type = fieldInfo.FieldType;

			if (_optional.HasValue && !_optional.Value && HasDefault)
				Runtime.FatalError("Specifying a default value forces a field to be optional");

			if (NumberFormat != null && !IsNumber(type))
			{
				let generic = type as SpecializedGenericType;
				if (generic != null && generic.UnspecializedType == typeof(List<>))
				{
					if (!IsNumber(generic.GetGenericArg(0)))
						Runtime.FatalError("List must have numeric values to use NumberFormat");
				}
				else if (generic != null && generic.UnspecializedType == typeof(Dictionary<>))
				{
					if (!IsNumber(generic.GetGenericArg(1)))
						Runtime.FatalError("Dictionary must have numeric values to use NumberFormat");
				}
				else
					Runtime.FatalError(scope $"Field type is not a number: {!IsNumber(generic.GetGenericArg(0))}");
			}

			bool IsNumber(Type type) => type.IsInteger || type.IsFloatingPoint;
		}
	}
}